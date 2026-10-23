variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name = "example"
}

run "create_false_outputs_null" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = output.id == null
    error_message = "id must be null when create is false."
  }
}

run "name_validation_rejects_uppercase" {
  command = plan

  variables {
    name = "Bad-Name"
  }

  expect_failures = [var.name]
}
