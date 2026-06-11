output "workload_identity_provider" {
  description = "Full resource name of the OIDC provider (projects/NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER). Pass directly to google-github-actions/auth as workload_identity_provider."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deploy_service_account_email" {
  description = "Email of the deploy service account. This module grants it no project roles; bind it to specific resources (Cloud Run services, Artifact Registry repos, buckets) where they are defined."
  value       = google_service_account.deploy.email
}

output "pool_name" {
  description = "Full resource name of the workload identity pool, for additional providers or principalSet bindings outside this module."
  value       = google_iam_workload_identity_pool.github.name
}
