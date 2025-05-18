locals {
  step_function_arn = try(resource.aws_sfn_state_machine.this[0].arn, null)
  event_bus         = try(var.events.event_bus, null) != null ? var.events.event_bus : "default"
  rule_prefix       = try(var.events.rule_prefix, null) != null ? var.events.rule_prefix : "port-aws-reflection-rule"
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each       = var.events != null ? var.resources : {}
  provider       = aws
  name           = "${local.rule_prefix}-${each.key}"
  event_bus_name = local.event_bus
  event_pattern  = jsonencode(each.value.events.pattern)
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = var.events != null ? var.resources : {}
  provider = aws
  rule     = resource.aws_cloudwatch_event_rule.this[each.key].name
  arn      = local.step_function_arn
  role_arn = resource.aws_iam_role.rule[0].arn

  input_transformer {
    input_paths = {
      arn = "$.detail.SourceArn"
    }

    input_template = "{\"${each.value.api.type_name}Identifier\": <arn> }"
  }
}

data "aws_iam_policy_document" "rule_execute" {
  count    = var.events != null ? 1 : 0
  provider = aws
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [local.step_function_arn]
  }
}

data "aws_iam_policy_document" "rule_assume" {
  count    = var.events != null ? 1 : 0
  provider = aws
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "rule" {
  count              = var.events != null ? 1 : 0
  provider           = aws
  name               = "port-aws-reflection-event-rule"
  assume_role_policy = data.aws_iam_policy_document.rule_assume[0].json
}

resource "aws_iam_policy" "rule" {
  count    = var.events != null ? 1 : 0
  provider = aws
  name     = "port-aws-reflection-event-rule-execute-step-function"
  policy   = data.aws_iam_policy_document.rule_execute[0].json
}

resource "aws_iam_role_policy_attachment" "rule" {
  count      = var.events != null ? 1 : 0
  provider   = aws
  role       = resource.aws_iam_role.rule[0].name
  policy_arn = resource.aws_iam_policy.rule[0].arn
}
