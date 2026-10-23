terraform {
  required_version = ">= 1.5.0"

  # Declare exactly the providers this module uses, with these bounds:
  #   aws        = { source = "hashicorp/aws", version = ">= 6.0, < 7.0" }
  #   google     = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
  #   cloudflare = { source = "cloudflare/cloudflare", version = ">= 5.0, < 6.0" }
  #   random     = { source = "hashicorp/random", version = ">= 3.5, < 4.0" }
  required_providers {}
}
