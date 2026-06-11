output "dataset_id" {
  description = "BigQuery dataset id of the audit log archive (project-relative, e.g. \"platform_prod_audit_logs\")."
  value       = google_bigquery_dataset.audit.dataset_id
}

output "sink_writer_identity" {
  description = "Service account identity the log sink writes as (member format, e.g. \"serviceAccount:...\"). Already granted roles/bigquery.dataEditor on the dataset by this module."
  value       = google_logging_project_sink.audit.writer_identity
}

output "sink_id" {
  description = "Fully qualified identifier of the project log sink."
  value       = google_logging_project_sink.audit.id
}
