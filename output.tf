output "webhook" {
  value = try(
    {
      url = resource.port_webhook.webhook[0].url
    }, null
  )
}

output "step_function" {
  value = try(
    {
      arn = resource.aws_sfn_state_machine.this[0].arn
    }, null
  )
}

output "headers" {
  value = var.headers
}

output "webhook_secret" {
  value     = local.webhook_secret
  sensitive = true
}
