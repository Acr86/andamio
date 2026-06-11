resource "google_sql_database_instance" "this" {
  name   = var.name
  region = var.region
  # Latest major on Cloud SQL. The AWS twin runs the newest major RDS offers;
  # the clouds genuinely differ in engine cadence (see ADR-0011).
  database_version = "POSTGRES_18"

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = var.ha ? "REGIONAL" : "ZONAL"
    disk_autoresize   = true
    user_labels       = var.labels

    ip_configuration {
      # Private services access on this VPC must exist before instance
      # creation; Terraform cannot infer that ordering from a string id,
      # so callers pass network_id derived from the network module's
      # service networking connection (or depend on that module).
      ipv4_enabled    = false
      private_network = var.network_id
      # mTLS, not just TLS: connector-based clients (the only supported
      # access path) present ephemeral client certificates automatically.
      ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    # Session-lifecycle and DDL logging for audit trails. Statement logging
    # is ddl-only and duration-only on purpose: DML text can embed row data,
    # and pgaudit at ddl scope records schema changes without it.
    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "-1"
    }

    database_flags {
      name  = "log_hostname"
      value = "on"
    }

    database_flags {
      name  = "log_min_messages"
      value = "error"
    }

    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }

    database_flags {
      name  = "log_statement"
      value = "ddl"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "pgaudit.log"
      value = "ddl"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.pitr
      # WAL retention for PITR is capped at 7 days on the Enterprise
      # edition, independent of how many daily backups are kept.
      transaction_log_retention_days = min(var.backup_retention_days, 7)

      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}
