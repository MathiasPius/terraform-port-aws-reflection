locals {
  webhook_url = try(var.step_function.external_webhook_url, null) != null ? var.step_function.external_webhook_url : try(resource.port_webhook.webhook[0].url, null)
}

data "aws_caller_identity" "this" {
  count    = var.step_function != null ? 1 : 0
  provider = aws
}

data "aws_region" "this" {
  count    = var.step_function != null ? 1 : 0
  provider = aws
}

resource "aws_sfn_state_machine" "this" {
  count    = var.step_function != null ? 1 : 0
  provider = aws
  name     = var.step_function.name
  role_arn = resource.aws_iam_role.step_function[0].arn

  definition = jsonencode({
    QueryLanguage = "JSONata"
    Comment       = "Port AWS Reflection"
    StartAt       = "DetermineResourceType"
    States = merge(
      {
        DetermineResourceType = {
          Type = "Choice"
          Choices = [for blueprint, aws_resource in var.resources :
            {
              Condition = "{% $states.input.${aws_resource.identifier != null ? aws_resource.identifier : "${aws_resource.type_name}Arn"} != null %}"
              Next      = "Fetch${aws_resource.type_name}s"
            }
          ]
        }
      },
      {
        for blueprint, aws_resource in var.resources : "Fetch${aws_resource.type_name}s" =>
        {
          Type = "Task"

          # This is a convoluted way to just lower case the first letter of the api action:
          #
          # e.g. "rds:DescribeDBInstances" -> "rds:describeDBInstances"
          Resource = "arn:aws:states:::aws-sdk:${join("",
            [
              split(":", aws_resource.api.action)[0], ":",
              lower(substr(split(":", aws_resource.api.action)[1], 0, 1)),
              substr(split(":", aws_resource.api.action)[1], 1, -1)
            ]
          )}"
          Arguments = {
            (aws_resource.api.parameter_name != null ? aws_resource.api.parameter_name : "${aws_resource.type_name}Identifier") = "{% $states.input.${aws_resource.identifier != null ? aws_resource.identifier : "${aws_resource.type_name}Arn"} %}"
          }
          Assign = {
            Type   = blueprint
            Action = "create"
            Data   = "{% $states.result.${aws_resource.type_name}s %}"
          }
          Catch = (length(aws_resource.api.delete_on_error) > 0 ? [
            {
              ErrorEquals = aws_resource.api.delete_on_error
              Assign = {
                Type   = blueprint
                Action = "delete"
                Data   = ["{% $states.input %}"]
              }
              Next = "UpdatePort"
            }
            ] : []
          )
          Next = "UpdatePort"
        }
      },
      {
        UpdatePort = {
          Type     = "Task"
          Resource = "arn:aws:states:::http:invoke"
          Arguments = {
            ApiEndpoint = local.webhook_url
            Method      = "POST"
            Authentication = {
              ConnectionArn = resource.aws_cloudwatch_event_connection.this[0].arn
            }
            Headers = {
              "Content-Type"          = "application/json"
              (var.headers.action)    = "{% $Action %}"
              (var.headers.blueprint) = "{% $Type %}"
              (var.headers.execution) = "{% $states.context.Execution.Name %}"
            }
            RequestBody = "{% $Data %}"
          }
          Retry = [
            {
              ErrorEquals = [
                "States.Http.StatusCode.429",
                "States.Http.StatusCode.502",
                "States.Http.StatusCode.503",
                "States.Http.StatusCode.504"
              ]
              BackoffRate     = 2,
              IntervalSeconds = 1
              MaxAttempts     = 3
              JitterStrategy  = "FULL"
            }
          ]
          End = true
        }
      }
    )
  })
}

resource "aws_cloudwatch_event_connection" "this" {
  count              = var.step_function != null ? 1 : 0
  provider           = aws
  name               = var.step_function.name
  description        = "Port RDS Ingest Connection for ${var.step_function.name}"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = var.headers.secret
      value = local.webhook_secret
    }
  }
}

resource "aws_iam_role" "step_function" {
  count              = var.step_function != null ? 1 : 0
  provider           = aws
  name               = var.step_function.name
  assume_role_policy = data.aws_iam_policy_document.step_function_assume[0].json
}

data "aws_iam_policy_document" "step_function_assume" {
  count    = var.step_function != null ? 1 : 0
  provider = aws
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = ["arn:aws:states:${data.aws_region.this[0].id}:${data.aws_caller_identity.this[0].account_id}:stateMachine:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.this[0].account_id]
    }
  }
}

data "aws_iam_policy_document" "step_function" {
  count    = var.step_function != null ? 1 : 0
  provider = aws
  statement {
    sid       = "AllowCallingPort"
    effect    = "Allow"
    actions   = ["states:InvokeHTTPEndpoint"]
    resources = ["arn:aws:states:${data.aws_region.this[0].id}:${data.aws_caller_identity.this[0].account_id}:stateMachine:*"]

    condition {
      test     = "StringEquals"
      variable = "states:HTTPMethod"
      values   = ["POST"]
    }

    condition {
      test     = "StringLike"
      variable = "states:HTTPEndpoint"
      values   = [local.webhook_url]
    }
  }

  statement {
    sid       = "AllowGetConnection"
    effect    = "Allow"
    actions   = ["events:RetrieveConnectionCredentials"]
    resources = [resource.aws_cloudwatch_event_connection.this[0].arn]
  }

  statement {
    sid       = "AllowGetApiKeySecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:*:*:secret:events!connection/*"]
  }

  statement {
    sid       = "AllowDescribeTypes"
    effect    = "Allow"
    actions   = [for aws_resource in var.resources : "${aws_resource.api.action}"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "step_function" {
  count    = var.step_function != null ? 1 : 0
  provider = aws
  name     = var.step_function.name
  policy   = data.aws_iam_policy_document.step_function[0].json
}

resource "aws_iam_role_policy_attachment" "step_function" {
  count      = var.step_function != null ? 1 : 0
  provider   = aws
  role       = resource.aws_iam_role.step_function[0].name
  policy_arn = resource.aws_iam_policy.step_function[0].arn
}
