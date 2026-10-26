# terraform-aws-lambda-function

Lambda function with scoped IAM, log retention, tracing, optional schedule, event sources and SSM-sourced environment

## Opinions

- Log group is created before the function with `log_retention_days` retention (default 30).
- X-Ray tracing is `Active`, with the tracing policy attached.
- ARM64 (`arm64`) unless `code.architecture` is set, or `code.type = "image"`, where the image decides.
- No function URL. Versions are published (`publish = true`).
- `schedule_expression` creates an EventBridge Scheduler schedule with `flexible_time_window` OFF and a dedicated scheduler role that may only `lambda:InvokeFunction` on this function. Role name is `<name>-scheduler` (name truncated to 54 characters so the role name stays within 64); its trust policy is restricted with `aws:SourceAccount`.
- Event sources with `type = "sqs"` (the default; also `kinesis`, `dynamodb`, `other`) automatically get `sqs:ReceiveMessage`, `DeleteMessage`, `GetQueueAttributes`, `ChangeMessageVisibility` scoped to that queue ARN. The decision uses `type`, not the ARN value, so it works when the queue is created in the same apply. Non-SQS sources need their read permissions supplied through `policy_json`.
- `ssm_environment` resolves SSM parameters with decryption at plan time. Resolved values land in the Lambda configuration (encrypted at rest by AWS) and in Terraform state; treat state accordingly.
- With `code.type = "s3"` and `track_s3_version = true`, the package object is read and its current version is deployed, so a new upload to the same key updates the function. The object must already exist when the plan runs (upload it in a separate step); after each new upload the next apply updates the function and publishes a new version. The bucket must have versioning on. Off by default.
- SQS event sources can set `function_response_types = ["ReportBatchItemFailures"]` so only failed messages are retried, and `maximum_batching_window_s` to wait for a fuller batch.
- The execution role is named after the function unless `role_name` is set.
- The code input is named `code`, not `source`, because `source` is a reserved Terraform name.

## Usage

```hcl
module "naming" {
  source  = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"
  context = var.context
}

module "lambda_function" {
  source  = "git::https://github.com/Olensys/terraform-aws-lambda-function.git?ref=v1.0.1"
  name    = module.naming.name
  context = var.context

  runtime = "python3.12"
  handler = "handler.handler"
  code    = { type = "zip_dir", path = "${path.module}/src/handler.py" }

  tags = module.naming.tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0, < 7.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | terraform-aws-modules/lambda/aws | 8.12.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_scheduler_schedule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.scheduler_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.scheduler_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_s3_object.package](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_object) | data source |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_code"></a> [code](#input\_code) | Code source. type is zip\_dir (path to a directory or file to zip), s3 (s3\_bucket and s3\_key of an existing package) or image (image\_uri of a container image). architecture is arm64 or x86\_64; null keeps arm64 for zip and lets the image decide for images. For s3, track\_s3\_version reads the object at plan time and deploys its current version, so the object must already exist when the plan runs (upload it in a separate step), and each new upload makes the next apply update the function and publish a new version. It needs versioning on the bucket and s3:GetObject and s3:GetObjectVersion for the caller. | <pre>object({<br/>    type             = string<br/>    path             = optional(string)<br/>    s3_bucket        = optional(string)<br/>    s3_key           = optional(string)<br/>    track_s3_version = optional(bool, false)<br/>    image_uri        = optional(string)<br/>    architecture     = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Resource name. Lowercase letters, digits and hyphens. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to create nothing. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Plain environment variables. Visible in plans and state; use ssm\_environment for secrets. | `map(string)` | `{}` | no |
| <a name="input_event_sources"></a> [event\_sources](#input\_event\_sources) | Event source mappings keyed by name. type (default sqs) sqs sources automatically get a scoped receive/delete policy; other types need policy\_json. maximum\_batching\_window\_s waits up to that many seconds to fill a batch; function\_response\_types may be ["ReportBatchItemFailures"] so only failed messages are retried. | <pre>map(object({<br/>    arn                       = string<br/>    type                      = optional(string, "sqs")<br/>    batch_size                = optional(number, 10)<br/>    max_concurrency           = optional(number)<br/>    filter_patterns           = optional(list(string))<br/>    maximum_batching_window_s = optional(number)<br/>    function_response_types   = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Function entrypoint, for example handler.handler. Must be null when code.type is image (enforced by a precondition on output arn). | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days. | `number` | `30` | no |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | Memory size in MB. | `number` | `256` | no |
| <a name="input_policy_json"></a> [policy\_json](#input\_policy\_json) | Additional IAM policy document (JSON) attached to the execution role. Null for none. | `string` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the execution role. Null uses the function name. Changing it replaces the role. | `string` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda runtime identifier, for example python3.12. Must be null when code.type is image (enforced by a precondition on output arn). | `string` | `null` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | EventBridge Scheduler expression (rate(...), cron(...) or at(...)). Null disables the schedule. | `string` | `null` | no |
| <a name="input_ssm_environment"></a> [ssm\_environment](#input\_ssm\_environment) | Map of environment variable name to SSM parameter name, resolved with decryption via a data source. Resolved values land in the Lambda configuration (encrypted at rest by AWS) and in state. | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto every taggable resource, applied last. | `map(string)` | `{}` | no |
| <a name="input_timeout_s"></a> [timeout\_s](#input\_timeout\_s) | Function timeout in seconds. | `number` | `30` | no |
| <a name="input_triggers"></a> [triggers](#input\_triggers) | Resource-based invoke permissions, keyed by statement id: principal (for example events.amazonaws.com) and source\_arn. | <pre>map(object({<br/>    principal  = string<br/>    source_arn = string<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Attach the function to a VPC. Null for no VPC attachment. | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the function. Null when create is false. |
| <a name="output_environment_variable_names"></a> [environment\_variable\_names](#output\_environment\_variable\_names) | Names (never values) of the environment variables set on the function. Null when create is false. |
| <a name="output_event_source_arns"></a> [event\_source\_arns](#output\_event\_source\_arns) | Event source ARNs by key. Null when create is false. |
| <a name="output_event_source_mapping"></a> [event\_source\_mapping](#output\_event\_source\_mapping) | Exact event source mapping map passed to the upstream module. Null when create is false. |
| <a name="output_id"></a> [id](#output\_id) | Identifier of the function (its name). Null when create is false. |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | Invoke ARN of the function, for API Gateway and similar integrations. Null when create is false. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Name of the function. Null when create is false. |
| <a name="output_policy_statements"></a> [policy\_statements](#output\_policy\_statements) | SQS consumer policy statements passed to the upstream module. Null when create is false. |
| <a name="output_qualified_arn"></a> [qualified\_arn](#output\_qualified\_arn) | ARN of the published function version. Null when create is false. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the execution role. Null when create is false. |
| <a name="output_tags"></a> [tags](#output\_tags) | Tags applied to every taggable resource, with context.extra\_tags merged in. Null when create is false. |
| <a name="output_tracing_mode"></a> [tracing\_mode](#output\_tracing\_mode) | Tracing mode passed to the upstream module. Null when create is false. |
<!-- END_TF_DOCS -->
