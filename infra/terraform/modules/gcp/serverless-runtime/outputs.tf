output "service_name" {
  description = "Name of the Cloud Run service."
  value       = google_cloud_run_v2_service.this.name
}

output "service_uri" {
  description = "Canonical run.app URI of the service. With internal ingress it only resolves from inside the VPC or via the internal load balancer."
  value       = google_cloud_run_v2_service.this.uri
}

output "service_account_email" {
  description = "Email of the dedicated runtime service account. Grant resource-scoped roles (e.g. Cloud SQL client, Secret Manager accessor on specific secrets) to this identity outside the module."
  value       = google_service_account.runtime.email
}

output "job_name" {
  description = "Name of the companion Cloud Run job, or null when enable_job is false."
  value       = one(google_cloud_run_v2_job.this[*].name)
}
