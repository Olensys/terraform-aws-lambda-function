output "id" {
  description = "Identifier of the primary resource. Null when create is false."
  value       = var.create ? var.name : null
}

output "name" {
  description = "Name of the primary resource. Null when create is false."
  value       = var.create ? var.name : null
}

# GCP modules replace this output with `self_link`. Replace `null` with the resource's ARN.
output "arn" {
  description = "ARN of the primary resource. Null when create is false."
  value       = null
}

output "tags" {
  description = "Tags applied to every taggable resource, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.tags : null
}
