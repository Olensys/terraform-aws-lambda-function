locals {
  tags = merge(var.context.extra_tags, var.tags)

  is_image = var.code.type == "image"

  scheduler_role_name = "${substr(var.name, 0, 54)}-scheduler"

  # Names only; values never leave the resolved map.
  environment_variable_names = sort(distinct(concat(keys(var.environment), keys(var.ssm_environment))))

  event_source_mapping = {
    for k, v in var.event_sources : k => merge(
      {
        event_source_arn = v.arn
        batch_size       = v.batch_size
      },
      v.max_concurrency == null ? {} : { scaling_config = { maximum_concurrency = v.max_concurrency } },
      v.maximum_batching_window_s == null ? {} : { maximum_batching_window_in_seconds = v.maximum_batching_window_s },
      v.function_response_types == null ? {} : { function_response_types = v.function_response_types },
      v.filter_patterns == null ? {} : { filter_criteria = [for p in v.filter_patterns : { pattern = p }] },
    )
  }

  policy_statements = {
    for k, v in var.event_sources : "sqs_${k}" => {
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
      resources = [v.arn]
    } if v.type == "sqs"
  }

  tracing_mode = "Active"

  track_s3_version = var.create && var.code.type == "s3" && var.code.track_s3_version
}

# Reads the current version of the package so a new upload to the same key updates the function.
data "aws_s3_object" "package" {
  count = local.track_s3_version ? 1 : 0

  bucket = var.code.s3_bucket
  key    = var.code.s3_key
}

# Values are fetched with decryption and end up in the Lambda configuration
# (encrypted at rest by AWS) and in state.
data "aws_ssm_parameter" "this" {
  for_each = var.create ? var.ssm_environment : {}

  name            = each.value
  with_decryption = true
}

module "this" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.12.0"

  create = var.create

  function_name = var.name
  role_name     = var.role_name
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.code.architecture != null ? [var.code.architecture] : (local.is_image ? null : ["arm64"])
  memory_size   = var.memory_mb
  timeout       = var.timeout_s
  publish       = true

  create_package = var.code.type == "zip_dir"
  source_path    = var.code.type == "zip_dir" ? var.code.path : null
  s3_existing_package = var.code.type == "s3" ? {
    bucket     = var.code.s3_bucket
    key        = var.code.s3_key
    version_id = local.track_s3_version ? data.aws_s3_object.package[0].version_id : null
  } : null
  package_type = local.is_image ? "Image" : "Zip"
  image_uri    = local.is_image ? var.code.image_uri : null

  environment_variables = merge(
    var.environment,
    { for k, d in data.aws_ssm_parameter.this : k => d.value },
  )

  vpc_subnet_ids         = var.vpc == null ? null : var.vpc.subnet_ids
  vpc_security_group_ids = var.vpc == null ? null : var.vpc.security_group_ids
  attach_network_policy  = var.vpc != null

  tracing_mode          = local.tracing_mode
  attach_tracing_policy = true

  use_existing_cloudwatch_log_group = false
  cloudwatch_logs_retention_in_days = var.log_retention_days

  allowed_triggers = {
    for k, t in var.triggers : k => {
      principal  = t.principal
      source_arn = t.source_arn
    }
  }
  create_lambda_function_url = false

  event_source_mapping = local.event_source_mapping

  attach_policy_json = var.policy_json != null
  policy_json        = var.policy_json

  attach_policy_statements = length([for k, v in var.event_sources : k if v.type == "sqs"]) > 0
  policy_statements        = local.policy_statements

  tags = local.tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "scheduler_assume" {
  count = var.create && var.schedule_expression != null ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "scheduler_invoke" {
  count = var.create && var.schedule_expression != null ? 1 : 0

  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [module.this.lambda_function_arn]
  }
}

resource "aws_iam_role" "scheduler" {
  count = var.create && var.schedule_expression != null ? 1 : 0

  name               = local.scheduler_role_name
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy" "scheduler" {
  count = var.create && var.schedule_expression != null ? 1 : 0

  name   = "invoke-function"
  role   = aws_iam_role.scheduler[0].id
  policy = data.aws_iam_policy_document.scheduler_invoke[0].json
}

resource "aws_scheduler_schedule" "this" {
  count = var.create && var.schedule_expression != null ? 1 : 0

  name                = var.name
  schedule_expression = var.schedule_expression

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = module.this.lambda_function_arn
    role_arn = aws_iam_role.scheduler[0].arn
  }
}
