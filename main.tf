locals {
  tags = merge(var.context.extra_tags, var.tags)

  is_image = var.code.type == "image"

  sqs_event_source_arns = {
    for k, v in var.event_sources : k => v.arn if startswith(v.arn, "arn:") && length(regexall("^arn:[^:]+:sqs:", v.arn)) > 0
  }

  scheduler_role_name = "${substr(var.name, 0, 53)}-scheduler"

  # Names only; values never leave the resolved map.
  environment_variable_names = sort(distinct(concat(keys(var.environment), keys(var.ssm_environment))))

  event_source_mapping = {
    for k, v in var.event_sources : k => merge(
      {
        event_source_arn = v.arn
        batch_size       = v.batch_size
      },
      v.max_concurrency == null ? {} : { scaling_config = { maximum_concurrency = v.max_concurrency } },
      v.filter_patterns == null ? {} : { filter_criteria = { filter = [for p in v.filter_patterns : { pattern = p }] } },
    )
  }

  policy_statements = {
    for k, arn in local.sqs_event_source_arns : "sqs_${k}" => {
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
      resources = [arn]
    }
  }
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
  handler       = var.handler
  runtime       = var.runtime
  architectures = local.is_image ? null : ["arm64"]
  memory_size   = var.memory_mb
  timeout       = var.timeout_s
  publish       = true

  create_package      = var.code.type == "zip_dir"
  source_path         = var.code.type == "zip_dir" ? var.code.path : null
  s3_existing_package = var.code.type == "s3" ? { bucket = var.code.s3_bucket, key = var.code.s3_key } : null
  package_type        = local.is_image ? "Image" : "Zip"
  image_uri           = local.is_image ? var.code.image_uri : null

  environment_variables = merge(
    var.environment,
    { for k, d in data.aws_ssm_parameter.this : k => d.value },
  )

  vpc_subnet_ids         = var.vpc == null ? null : var.vpc.subnet_ids
  vpc_security_group_ids = var.vpc == null ? null : var.vpc.security_group_ids
  attach_network_policy  = var.vpc != null

  tracing_mode          = "Active"
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

  attach_policy_statements = length(local.policy_statements) > 0
  policy_statements        = local.policy_statements

  tags = local.tags
}

data "aws_iam_policy_document" "scheduler_assume" {
  count = var.create && var.schedule_expression != null ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
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
