# Changelog

## [1.1.0](https://github.com/Olensys/terraform-aws-lambda-function/compare/v1.0.3...v1.1.0) (2026-10-26)


### Features

* add s3 version tracking, batch failure reporting, architectures and role_name ([#6](https://github.com/Olensys/terraform-aws-lambda-function/issues/6)) ([ed066f8](https://github.com/Olensys/terraform-aws-lambda-function/commit/ed066f879a1b7a1eb8f896c15fcf7267620d6951))

## [1.0.3](https://github.com/Olensys/terraform-aws-lambda-function/compare/v1.0.2...v1.0.3) (2026-10-24)


### Bug Fixes

* **examples:** unique application slug so concurrent integration runs do not collide ([#3](https://github.com/Olensys/terraform-aws-lambda-function/issues/3)) ([d63530b](https://github.com/Olensys/terraform-aws-lambda-function/commit/d63530b6f769d75ae6ecbbc280dc53bc92c558c2))

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
