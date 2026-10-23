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
      output.event_source_arns == null, output.sqs_event_source_arns == null,
      output.environment_variable_names == null, output.tags == null,
    ])
    error_message = "All outputs must be null when create is false."
  }

  assert {
    condition     = length(aws_scheduler_schedule.this) == 0 && length(aws_iam_role.scheduler) == 0 && length(data.aws_ssm_parameter.this) == 0
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
        arn = "arn:aws:kinesis:eu-west-1:123456789012:stream/s"
      }
    }
  }

  assert {
    condition     = output.event_source_arns == { jobs = "arn:aws:sqs:eu-west-1:123456789012:jobs", stream = "arn:aws:kinesis:eu-west-1:123456789012:stream/s" }
    error_message = "event_source_arns must list every configured source."
  }

  assert {
    condition     = output.sqs_event_source_arns == { jobs = "arn:aws:sqs:eu-west-1:123456789012:jobs" }
    error_message = "Only SQS sources receive the scoped consumer policy."
  }
}

run "test_ssm_environment_resolved" {
  command = plan

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
    error_message = "Resolved environment variable names must reach the function configuration."
  }
}

run "test_tracing_active" {
  command = plan

  # tracing_mode = "Active" is a literal passed to the upstream module and is
  # not visible to assertions (child module); tests/complete.tftest.hcl applies it.
  # Here we only assert the module plans cleanly with the opinions hardcoded.
  assert {
    condition     = length(output.tags) == 0 && length(data.aws_ssm_parameter.this) == 0
    error_message = "Function must plan with default opinions."
  }
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

  expect_failures = [var.code]
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
