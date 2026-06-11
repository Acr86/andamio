# The values the CI pipeline must be configured with after an apply.

output "registry_url" {
  description = "Docker registry URL CI pushes application images to."
  value       = module.registry.repository_url
}

output "service_uri" {
  description = "Cloud Run URI of the application service. Internal ingress: resolves only through the internal load balancer or from inside the VPC."
  value       = module.runtime.service_uri
}

output "workload_identity_provider" {
  description = "OIDC provider resource name to pass to google-github-actions/auth."
  value       = module.cicd_identity.workload_identity_provider
}

output "deploy_service_account_email" {
  description = "Service account GitHub Actions impersonates to deploy this environment."
  value       = module.cicd_identity.deploy_service_account_email
}
