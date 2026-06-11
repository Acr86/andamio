output "repository_id" {
  description = "Fully qualified repository id (projects/<project>/locations/<location>/repositories/<name>). Use for IAM bindings."
  value       = google_artifact_registry_repository.this.id
}

output "repository_url" {
  description = "Docker registry URL to push to and pull from (<location>-docker.pkg.dev/<project>/<name>)."
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev/${google_artifact_registry_repository.this.project}/${google_artifact_registry_repository.this.repository_id}"
}
