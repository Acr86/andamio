# The values the CI pipeline must be configured with after an apply.

output "registry_url" {
  description = "ECR repository URL CI pushes application images to."
  value       = module.registry.repository_url
}

output "service_url" {
  description = "HTTPS URL of the App Runner service (private ingress)."
  value       = module.runtime.service_url
}

output "deploy_role_arn" {
  description = "IAM role GitHub Actions assumes via OIDC to deploy this environment."
  value       = module.cicd_identity.deploy_role_arn
}

output "audit_log_group_name" {
  description = "CloudWatch log group the application writes audit events to."
  value       = module.audit_log_sink.log_group_name
}
