locals {
  # BigQuery dataset ids cannot contain hyphens.
  dataset_id = "${replace(var.name_prefix, "-", "_")}_audit_logs"

  # Retention is enforced with PARTITION expiration, not table expiration:
  # the sink streams into a small set of long-lived, day-partitioned tables,
  # so a table-level expiration would eventually delete current data along
  # with old data. Partition expiration ages out exactly one day at a time.
  retention_ms = var.retention_years == 0 ? null : var.retention_years * 365 * 24 * 60 * 60 * 1000
}

resource "google_bigquery_dataset" "audit" {
  project    = var.project_id
  dataset_id = local.dataset_id
  location   = var.location

  friendly_name = "${var.name_prefix} audit log archive"
  description   = "Append-only audit log archive populated by the ${var.name_prefix}-audit-sink log sink. Day-partitioned; retention enforced via partition expiration."

  default_partition_expiration_ms = local.retention_ms

  # Destroying the module must never take the audit trail with it.
  delete_contents_on_destroy = false

  dynamic "default_encryption_configuration" {
    for_each = var.kms_key_name == null ? [] : [var.kms_key_name]
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }

  labels = {
    purpose         = "audit-log-archive"
    managed-by      = "terraform"
    retention-years = tostring(var.retention_years)
  }
}

resource "google_logging_project_sink" "audit" {
  project = var.project_id
  name    = "${var.name_prefix}-audit-sink"
  filter  = var.log_filter

  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.audit.dataset_id}"

  # A dedicated per-sink service account, never the project-wide shared one:
  # the grant below is then scoped to exactly this identity.
  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "sink_writer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.audit.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.audit.writer_identity
}
