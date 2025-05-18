variable "webhook" {
  description = "Port Webhook Configuration. If not set, no webhook will be created."
  type = object({
    identifier  = string,
    name        = optional(string, null)
    description = optional(string, null)
    icon        = optional(string, "AWS")
    enabled     = optional(bool, true)
  })

  default  = null
  nullable = true
}

variable "step_function" {
  type = object({
    name = optional(string, "port-aws-reflection-step-function")

    # Only define this, if you are not provisioning the webhook
    # in this same module.
    external_webhook_url = optional(string)
  })

  default  = null
  nullable = true

  validation {
    condition     = (try(var.step_function.external_webhook_url, null) == null) != (try(var.webhook, null) == null)
    error_message = "You must specify either 'webhook' or 'step_function.external_webhook_url'"
  }
}

variable "resources" {
  type = map(object({
    api = optional(object({
      # Defaults to {type_name}Identifier
      identifier = optional(string)

      # DbInstance for example.
      type_name = string

      arn             = string
      iam_action      = string
      delete_on_error = optional(list(string), [])
    }))
    mapping = optional(object({
      # Defaults to {type_name}Arn
      identifier = optional(string)

      # Defaults to {type_name}Identifier
      title = optional(string)

      # Scary, but this is the default for webhooks.
      delete_dependents = optional(bool, true)

      properties = optional(map(string))
      relations  = optional(map(string))
      })
    )
  }))

  validation {
    condition     = try(var.step_function, null) != null || alltrue([for resource in values(var.resources) : try(resource.api, null) == null])
    error_message = "Specifying a resource 'api' does nothing, unless 'step_function' is also defined."
  }

  validation {
    condition     = try(var.webhook, null) != null || alltrue([for resource in values(var.resources) : try(resource.mapping, null) == null])
    error_message = "Specifying a resource 'mapping' does nothing, unless 'webhook' is also defined."
  }

  validation {
    condition     = try(var.webhook, null) == null || alltrue([for resource in values(var.resources) : try(resource.mapping, null) != null])
    error_message = "When deploying the 'webhook', you must specify a mapping for all resources."
  }

  validation {
    condition     = try(var.step_function, null) == null || alltrue([for resource in values(var.resources) : try(resource.api, null) != null])
    error_message = "When deploying the 'step_function', you must specify an api for all resources."
  }
}

variable "webhook_secret" {
  description = "Port Webhook Secret. If not defined, and 'webhook' is configured, one will be randomly generated."
  type        = string
  sensitive   = true
  nullable    = true
  default     = null

  validation {
    condition     = var.webhook_secret != null || try(var.webhook, null) != null
    error_message = "If not deploying the webhook, you must specify the webhook_secret"
  }
}

variable "headers" {
  description = "Headers used for communicating metadata and API Keys from AWS"
  type = object({
    execution = optional(string, "x-port-aws-reflection-id")
    blueprint = optional(string, "x-port-aws-reflection-blueprint")
    secret    = optional(string, "x-port-aws-reflection-secret")
    action    = optional(string, "x-port-aws-reflection-action")
  })
  default = {
    execution = "x-port-aws-reflection-id"
    blueprint = "x-port-aws-reflection-blueprint"
    secret    = "x-port-aws-reflection-secret"
    action    = "x-port-aws-reflection-action"
  }
}
