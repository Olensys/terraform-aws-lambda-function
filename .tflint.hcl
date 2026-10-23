plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Delete the ruleset you do not use.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Delete the ruleset you do not use.
plugin "google" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
