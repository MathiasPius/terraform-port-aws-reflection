output "webhook" {
  value = {
    url = resource.port_webhook.webhook[0].url
  }
}

output "step_function" {
  value = {
    arn = resource.aws_sfn_state_machine.this[0].arn
  }
}

output "headers" {
  value = var.headers
}

output "webhook_secret" {
  value     = local.webhook_secret
  sensitive = true
}
