output "id" {
  description = "Identifier of the function (its name). Null when create is false."
  value       = var.create ? module.this.lambda_function_name : null
}

output "name" {
  description = "Name of the function. Null when create is false."
  value       = var.create ? module.this.lambda_function_name : null
}

output "arn" {
  description = "ARN of the function. Null when create is false."
  value       = var.create ? module.this.lambda_function_arn : null
}

output "invoke_arn" {
  description = "Invoke ARN of the function, for API Gateway and similar integrations. Null when create is false."
  value       = var.create ? module.this.lambda_function_invoke_arn : null
}

output "qualified_arn" {
  description = "ARN of the published function version. Null when create is false."
  value       = var.create ? module.this.lambda_function_qualified_arn : null
}

output "role_arn" {
  description = "ARN of the execution role. Null when create is false."
  value       = var.create ? module.this.lambda_role_arn : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group. Null when create is false."
  value       = var.create ? module.this.lambda_cloudwatch_log_group_name : null
}

output "event_source_arns" {
  description = "Event source ARNs by key. Null when create is false."
  value       = var.create ? { for k, v in var.event_sources : k => v.arn } : null
}

output "sqs_event_source_arns" {
  description = "Subset of event source ARNs that receive the scoped SQS consumer policy. Null when create is false."
  value       = var.create ? local.sqs_event_source_arns : null
}

output "environment_variable_names" {
  description = "Names (never values) of the environment variables set on the function. Null when create is false."
  value       = var.create ? local.environment_variable_names : null
}

output "tags" {
  description = "Tags applied to every taggable resource, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.tags : null
}
