# Changelog

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
