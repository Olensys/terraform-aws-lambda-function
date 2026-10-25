variable "name" {
  description = "Resource name. Lowercase letters, digits and hyphens."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{1,64}$", var.name))
    error_message = "name must match ^[a-z0-9-]{1,64}$."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "create" {
  description = "Whether to create any resources. Set false to create nothing."
  type        = bool
  default     = true
}

variable "runtime" {
  description = "Lambda runtime identifier, for example python3.12. Must be null when code.type is image (enforced by a precondition on output arn)."
  type        = string
  default     = null
}

variable "handler" {
  description = "Function entrypoint, for example handler.handler. Must be null when code.type is image (enforced by a precondition on output arn)."
  type        = string
  default     = null
}

variable "code" {
  description = "Code source. type is zip_dir (path to a directory or file to zip), s3 (s3_bucket and s3_key of an existing package) or image (image_uri of a container image). For s3, track_s3_version reads the object and deploys its current version, so uploading a new zip to the same key updates the function; it needs versioning on the bucket and s3:GetObject and s3:GetObjectVersion for the caller."
  type = object({
    type             = string
    path             = optional(string)
    s3_bucket        = optional(string)
    s3_key           = optional(string)
    track_s3_version = optional(bool, false)
    image_uri        = optional(string)
  })
  validation {
    condition     = contains(["zip_dir", "s3", "image"], var.code.type)
    error_message = "code.type must be one of zip_dir, s3, image."
  }
  validation {
    condition = (
      (var.code.type == "zip_dir" && var.code.path != null) ||
      (var.code.type == "s3" && var.code.s3_bucket != null && var.code.s3_key != null) ||
      (var.code.type == "image" && var.code.image_uri != null) ||
      !contains(["zip_dir", "s3", "image"], var.code.type)
    )
    error_message = "code.path is required for zip_dir, code.s3_bucket and code.s3_key for s3, code.image_uri for image."
  }
}

variable "architectures" {
  description = "Instruction set architectures. Null means [\"arm64\"] for zip functions and the image's own for container images."
  type        = list(string)
  default     = null
  validation {
    condition     = var.architectures == null ? true : (length(var.architectures) == 1 && contains(["arm64", "x86_64"], var.architectures[0]))
    error_message = "architectures must be [\"arm64\"] or [\"x86_64\"]."
  }
}

variable "role_name" {
  description = "Name of the execution role. Null uses the function name. Changing it replaces the role."
  type        = string
  default     = null
}

variable "memory_mb" {
  description = "Memory size in MB."
  type        = number
  default     = 256
  validation {
    condition     = var.memory_mb >= 128 && var.memory_mb <= 10240
    error_message = "memory_mb must be between 128 and 10240."
  }
}

variable "timeout_s" {
  description = "Function timeout in seconds."
  type        = number
  default     = 30
  validation {
    condition     = var.timeout_s >= 1 && var.timeout_s <= 900
    error_message = "timeout_s must be between 1 and 900."
  }
}

variable "environment" {
  description = "Plain environment variables. Visible in plans and state; use ssm_environment for secrets."
  type        = map(string)
  default     = {}
}

variable "ssm_environment" {
  description = "Map of environment variable name to SSM parameter name, resolved with decryption via a data source. Resolved values land in the Lambda configuration (encrypted at rest by AWS) and in state."
  type        = map(string)
  default     = {}
}

variable "vpc" {
  description = "Attach the function to a VPC. Null for no VPC attachment."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "triggers" {
  description = "Resource-based invoke permissions, keyed by statement id: principal (for example events.amazonaws.com) and source_arn."
  type = map(object({
    principal  = string
    source_arn = string
  }))
  default = {}
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression (rate(...), cron(...) or at(...)). Null disables the schedule."
  type        = string
  default     = null
}

variable "event_sources" {
  description = "Event source mappings keyed by name. type (default sqs) sqs sources automatically get a scoped receive/delete policy; other types need policy_json. maximum_batching_window_s waits up to that many seconds to fill a batch; function_response_types may be [\"ReportBatchItemFailures\"] so only failed messages are retried."
  type = map(object({
    arn                       = string
    type                      = optional(string, "sqs")
    batch_size                = optional(number, 10)
    max_concurrency           = optional(number)
    filter_patterns           = optional(list(string))
    maximum_batching_window_s = optional(number)
    function_response_types   = optional(list(string))
  }))
  default = {}
  validation {
    condition     = alltrue([for k, v in var.event_sources : contains(["sqs", "kinesis", "dynamodb", "other"], v.type)])
    error_message = "event_sources[*].type must be one of sqs, kinesis, dynamodb, other."
  }
  validation {
    condition     = alltrue([for k, v in var.event_sources : v.function_response_types == null ? true : alltrue([for t in v.function_response_types : t == "ReportBatchItemFailures"])])
    error_message = "event_sources[*].function_response_types may only contain ReportBatchItemFailures."
  }
}

variable "policy_json" {
  description = "Additional IAM policy document (JSON) attached to the execution role. Null for none."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value CloudWatch Logs accepts."
  }
}

variable "tags" {
  description = "Tags merged onto every taggable resource, applied last."
  type        = map(string)
  default     = {}
}
