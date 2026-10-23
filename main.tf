# Primary upstream call or primary resource is named `this`.
# Gate every resource on var.create (count = var.create ? 1 : 0).

locals {
  # Merge onto every taggable resource, with var.tags applied last.
  tags = merge(var.context.extra_tags, var.tags)
}
