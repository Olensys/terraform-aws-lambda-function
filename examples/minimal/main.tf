module "naming" {
  source = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.0"

  context = local.context
}

locals {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
}

module "this" {
  source = "../../"

  name    = module.naming.name
  context = local.context
  tags    = module.naming.tags

  runtime = "python3.12"
  handler = "handler.handler"
  code = {
    type = "zip_dir"
    path = "${path.module}/src/handler.py"
  }
}
