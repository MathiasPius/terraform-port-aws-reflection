locals {
  webhook_secret = var.webhook_secret != null ? var.webhook_secret : resource.random_password.webhook_secret[0].result
}

resource "random_password" "webhook_secret" {
  count   = var.webhook_secret == null && var.webhook != null ? 1 : 0
  length  = 32
  special = true
}

resource "port_webhook" "webhook" {
  count       = var.webhook != null ? 1 : 0
  provider    = port-labs
  identifier  = var.webhook.identifier
  title       = var.webhook.name
  description = var.webhook.description
  icon        = var.webhook.icon
  enabled     = var.webhook.enabled

  mappings = flatten([for blueprint, resource in var.resources :
    [
      {
        operation = {
          type = "create"
        }
        items_to_parse = ".body"
        filter         = ".item != null and .headers.\"${var.headers.action}\" == \"create\" and .headers.\"${var.headers.blueprint}\" == \"${blueprint}\""
        blueprint      = blueprint
        entity = merge(
          {
            identifier = ".item.${resource.identifier != null ? resource.identifier : "${resource.type_name}Arn"}"
            properties = merge(
              resource.mapping.properties
            )
            relations = resource.mapping.relations
          },
          resource.mapping.title != null ? {
            title = ".item.${resource.mapping.title}"
          } : {}
        )
      },
      {
        operation = {
          type              = "delete"
          delete_dependents = resource.mapping.delete_dependents
        }
        items_to_parse = ".body"
        filter         = ".item != null and .headers.\"${var.headers.action}\" == \"delete\" and .headers.\"${var.headers.blueprint}\" == \"${blueprint}\""
        blueprint      = blueprint
        entity = {
          identifier = ".item.${resource.identifier != null ? resource.identifier : "${resource.type_name}Arn"}"
        }
      }
    ]
  ])

  security = {
    secret                  = local.webhook_secret
    signature_algorithm     = "plain"
    signature_header_name   = var.headers.secret
    request_identifier_path = ".headers.${var.headers.execution}"
  }

  lifecycle {
    # This is never saved to terraform state (in the webhook), so without this
    # every apply will trigger an update.
    ignore_changes = [security.secret]
  }
}
