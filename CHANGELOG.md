# Changelog

## [1.0.2](https://github.com/Olensys/terraform-aws-lambda-function/compare/v1.0.1...v1.0.2) (2026-10-24)


### Bug Fixes

* **examples:** pin naming module to v1.0.1 ([000acf6](https://github.com/Olensys/terraform-aws-lambda-function/commit/000acf6ee49542e5337409122bee61d41432994c))
* run integration on change and weekly instead of nightly ([6f7fcc1](https://github.com/Olensys/terraform-aws-lambda-function/commit/6f7fcc1e01561131c137fc79b0a98f84a7f6a8b2))

## 1.0.1

### Fixes

- render declared provider constraints and skip .terraform in trivy scans
- filter criteria shape, typed event sources, output precondition, scheduler trust condition and test coverage
- declare required_version and providers in examples/minimal

## 1.0.0

- Lambda function with scoped IAM, log group with retention, active tracing, ARM64 default.
- Zip directory, S3 and container image code sources.
- Optional EventBridge Scheduler schedule with a dedicated invoke-only role.
- Event source mappings with scoped SQS consumer permissions, resource-based triggers, optional VPC and extra policy.
- SSM-sourced environment variables.
