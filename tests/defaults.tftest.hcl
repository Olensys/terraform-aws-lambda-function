mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "mocked"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/example"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn           = "arn:aws:lambda:eu-west-1:123456789012:function:example"
      qualified_arn = "arn:aws:lambda:eu-west-1:123456789012:function:example:1"
      invoke_arn    = "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-1:123456789012:function:example/invocations"
    }
  }

  mock_data "aws_s3_object" {
    defaults = {
      version_id = "v1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"lambda:InvokeFunction\",\"Resource\":\"arn:aws:lambda:eu-west-1:123456789012:function:example\"}]}"
    }
  }

  mock_data "aws_iam_policy" {
    defaults = {
      policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"lambda:InvokeFunction\",\"Resource\":\"arn:aws:lambda:eu-west-1:123456789012:function:example\"}]}"
    }
  }
}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name    = "example"
  runtime = "python3.12"
  handler = "handler.handler"
  code = {
    type = "zip_dir"
    path = "examples/minimal/src/handler.py"
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  variables {
    create              = false
    schedule_expression = "rate(5 minutes)"
    ssm_environment     = { SECRET = "/example/secret" }
  }

  assert {
    condition = alltrue([
      output.id == null, output.name == null, output.arn == null, output.invoke_arn == null,
      output.qualified_arn == null, output.role_arn == null, output.log_group_name == null,
      output.event_source_arns == null, output.event_source_mapping == null,
      output.policy_statements == null, output.tracing_mode == null,
      output.environment_variable_names == null, output.tags == null,
    ])
    error_message = "All outputs must be null when create is false."
  }

  assert {
    condition     = length(aws_scheduler_schedule.this) == 0 && length(aws_iam_role.scheduler) == 0 && length(aws_iam_role_policy.scheduler) == 0 && length(data.aws_ssm_parameter.this) == 0
    error_message = "No root resources or data sources may be planned when create is false."
  }
}

run "test_schedule_creates_scheduler_and_permission" {
  command = plan

  variables {
    schedule_expression = "rate(5 minutes)"
  }

  assert {
    condition     = aws_scheduler_schedule.this[0].schedule_expression == "rate(5 minutes)" && aws_scheduler_schedule.this[0].flexible_time_window[0].mode == "OFF"
    error_message = "Scheduler schedule must exist with the given expression and flexible window OFF."
  }

  assert {
    condition     = one(data.aws_iam_policy_document.scheduler_invoke[0].statement[*].actions) == toset(["lambda:InvokeFunction"]) && length(data.aws_iam_policy_document.scheduler_invoke[0].statement) == 1
    error_message = "Scheduler role policy document must allow only lambda:InvokeFunction."
  }

}

run "test_no_schedule_by_default" {
  command = plan

  assert {
    condition     = length(aws_scheduler_schedule.this) == 0 && length(aws_iam_role.scheduler) == 0
    error_message = "No schedule resources without schedule_expression."
  }
}

run "test_sqs_event_source_mapping" {
  command = plan

  variables {
    event_sources = {
      jobs = {
        arn             = "arn:aws:sqs:eu-west-1:123456789012:jobs"
        max_concurrency = 5
        filter_patterns = ["{\"body\":{\"kind\":[\"a\"]}}"]
      }
      stream = {
        arn  = "arn:aws:kinesis:eu-west-1:123456789012:stream/s"
        type = "kinesis"
      }
    }
  }

  assert {
    condition     = output.event_source_mapping["jobs"].scaling_config.maximum_concurrency == 5 && output.event_source_mapping["jobs"].filter_criteria[0].pattern == "{\"body\":{\"kind\":[\"a\"]}}" && output.event_source_mapping["jobs"].batch_size == 10
    error_message = "Mapping passed upstream must carry scaling_config, a list of filter patterns and the default batch size."
  }

  assert {
    condition     = !contains(keys(output.event_source_mapping["stream"]), "scaling_config") && !contains(keys(output.event_source_mapping["stream"]), "filter_criteria")
    error_message = "Optional keys must be absent when unset."
  }

  assert {
    condition     = keys(output.policy_statements) == ["sqs_jobs"] && output.policy_statements["sqs_jobs"].resources == ["arn:aws:sqs:eu-west-1:123456789012:jobs"] && contains(output.policy_statements["sqs_jobs"].actions, "sqs:ReceiveMessage")
    error_message = "Only the sqs-typed source gets a policy statement, scoped to its queue ARN."
  }
}

run "test_batch_failure_reporting_and_window" {
  command = plan

  variables {
    event_sources = {
      jobs = {
        arn                       = "arn:aws:sqs:eu-west-1:123456789012:jobs"
        maximum_batching_window_s = 5
        function_response_types   = ["ReportBatchItemFailures"]
      }
      plain = {
        arn = "arn:aws:sqs:eu-west-1:123456789012:plain"
      }
    }
  }

  assert {
    condition     = output.event_source_mapping["jobs"].maximum_batching_window_in_seconds == 5 && join(",", output.event_source_mapping["jobs"].function_response_types) == "ReportBatchItemFailures"
    error_message = "Mapping passed upstream must carry the batching window and function response types."
  }

  assert {
    condition     = !contains(keys(output.event_source_mapping["plain"]), "maximum_batching_window_in_seconds") && !contains(keys(output.event_source_mapping["plain"]), "function_response_types")
    error_message = "Both keys must be absent when unset."
  }
}

run "test_function_response_types_validation" {
  command = plan

  variables {
    event_sources = {
      jobs = {
        arn                     = "arn:aws:sqs:eu-west-1:123456789012:jobs"
        function_response_types = ["Other"]
      }
    }
  }

  expect_failures = [var.event_sources]
}

run "test_s3_version_tracked_when_enabled" {
  command = plan

  variables {
    runtime = "python3.12"
    handler = "handler.handler"
    code = {
      type             = "s3"
      s3_bucket        = "artifacts"
      s3_key           = "fn.zip"
      track_s3_version = true
    }
  }

  assert {
    condition     = length(data.aws_s3_object.package) == 1 && data.aws_s3_object.package[0].bucket == "artifacts" && data.aws_s3_object.package[0].key == "fn.zip"
    error_message = "The package object must be read when track_s3_version is true."
  }
}

run "test_s3_version_not_read_by_default" {
  command = plan

  variables {
    code = { type = "s3", s3_bucket = "artifacts", s3_key = "fn.zip" }
  }

  assert {
    condition     = length(data.aws_s3_object.package) == 0
    error_message = "The package object must not be read unless track_s3_version is true."
  }
}

run "test_architecture_validation" {
  command = plan

  variables {
    code = { type = "zip_dir", path = "examples/minimal/src/handler.py", architecture = "mips" }
  }

  expect_failures = [var.code]
}

run "test_large_sqs_batch_needs_window" {
  command = plan

  variables {
    event_sources = {
      jobs = { arn = "arn:aws:sqs:eu-west-1:123456789012:jobs", batch_size = 100 }
    }
  }

  expect_failures = [var.event_sources]
}

run "test_architecture_and_role_name_accepted" {
  command = plan

  # SMOKE: the mocked upstream hides the role and architecture; this only
  # proves the inputs plan.
  variables {
    code      = { type = "zip_dir", path = "examples/minimal/src/handler.py", architecture = "x86_64" }
    role_name = "example-lambda"
  }

  assert {
    condition     = output.name == "example"
    error_message = "A custom architecture and role name must plan cleanly."
  }
}

run "test_ssm_environment_resolved" {
  command = plan

  # SMOKE: the merged value map is sensitive and not visible; asserts the data
  # source read and the resulting variable names only.

  variables {
    environment     = { LOG_LEVEL = "info" }
    ssm_environment = { DB_PASSWORD = "/example/db/password" }
  }

  assert {
    condition     = data.aws_ssm_parameter.this["DB_PASSWORD"].name == "/example/db/password" && data.aws_ssm_parameter.this["DB_PASSWORD"].with_decryption == true
    error_message = "SSM parameter must be read by name with decryption."
  }

  assert {
    condition     = join(",", output.environment_variable_names) == "DB_PASSWORD,LOG_LEVEL"
    error_message = "Environment variable names must be the union of environment and ssm_environment keys."
  }
}

run "test_tracing_active" {
  command = plan

  # SMOKE: tracing_mode is passed to the child module and its effect is not
  # visible; asserts the value the module passes and a clean plan.
  assert {
    condition     = output.tracing_mode == "Active" && length(output.tags) == 0
    error_message = "tracing_mode passed upstream must be Active."
  }
}

run "test_tracing_pass_through" {
  command = plan

  variables {
    tracing_mode = "PassThrough"
  }

  assert {
    condition     = output.tracing_mode == "PassThrough"
    error_message = "tracing_mode PassThrough must be passed upstream."
  }
}

run "test_tracing_mode_validation" {
  command = plan

  variables {
    tracing_mode = "Off"
  }

  expect_failures = [var.tracing_mode]
}

run "test_source_type_validation" {
  command = plan

  variables {
    code = { type = "url", path = "x" }
  }

  expect_failures = [var.code]
}

run "test_image_rejects_runtime" {
  command = plan

  variables {
    code = { type = "image", image_uri = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/x:1" }
  }

  expect_failures = [output.arn]
}

run "test_two_instances_distinct_role_names" {
  command = plan

  variables {
    name                = "alpha"
    schedule_expression = "rate(1 hour)"
  }

  assert {
    condition     = aws_iam_role.scheduler[0].name == "alpha-scheduler"
    error_message = "Scheduler role name must derive from name."
  }
}

run "test_two_instances_distinct_role_names_second" {
  command = plan

  variables {
    name                = "beta"
    schedule_expression = "rate(1 hour)"
  }

  assert {
    condition     = aws_iam_role.scheduler[0].name == "beta-scheduler"
    error_message = "Scheduler role name must derive from name and differ from other instances."
  }
}

run "test_name_length_validation" {
  command = plan

  variables {
    name = join("", [for i in range(65) : "a"])
  }

  expect_failures = [var.name]
}

run "name_validation_rejects_uppercase" {
  command = plan

  variables {
    name = "Bad-Name"
  }

  expect_failures = [var.name]
}

run "test_tags_contract" {
  command = plan

  variables {
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { Owner = "y", Team = "z" }
    }
    tags = { Owner = "x" }
  }

  assert {
    condition     = output.tags.Owner == "x" && output.tags.Team == "z"
    error_message = "var.tags must win over context.extra_tags."
  }
}
