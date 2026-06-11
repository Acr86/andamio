# gcp/audit-log-sink

Routes a project's structured audit logs into a dedicated, day-partitioned BigQuery dataset that acts as a long-term, append-only archive. The module creates the destination dataset, a project log sink with its own writer identity, and the single IAM grant that connects the two — nothing else. Retention is expressed in years and enforced by BigQuery partition expiration, so dropping aged-out data is a metadata operation instead of a scan-and-delete job.

## Usage

```hcl
module "audit_log_sink" {
  source = "../../modules/gcp/audit-log-sink"

  name_prefix     = "platform-prod"
  project_id      = "platform-prod-123456"
  location        = "europe-west1"
  retention_years = 7

  # Optional: customer-managed encryption for the archive dataset.
  kms_key_name = "projects/platform-prod-123456/locations/europe-west1/keyRings/platform/cryptoKeys/bq-audit"
}
```

To archive a different log shape, override the filter:

```hcl
  log_filter = "logName=~\"projects/.+/logs/audit\" AND severity >= \"NOTICE\""
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | `string` | — | Prefix for resource names; hyphens become underscores in the dataset id. |
| `project_id` | `string` | — | Project hosting both the sink and the dataset. |
| `location` | `string` | — | BigQuery dataset location (`US`, `EU`, or a region). |
| `retention_years` | `number` | `7` | Partition retention in whole years; `0` keeps data forever. |
| `log_filter` | `string` | `logName=~"projects/.+/logs/audit"` | Which entries the sink exports. Must not be empty. |
| `kms_key_name` | `string` | `null` | Optional CMEK key for the dataset; key location must match the dataset location. |

## Outputs

| Name | Description |
|---|---|
| `dataset_id` | Dataset id of the audit archive. |
| `sink_writer_identity` | The sink's dedicated writer service account (member format). |
| `sink_id` | Fully qualified id of the log sink. |

## Opinions

- **Audit trails are append-only.** The archive is only ever written to by the sink; the module grants no human or application role on the dataset, and `delete_contents_on_destroy` stays `false` so a `terraform destroy` cannot take the evidence with it.
- **Writer identity gets exactly one role on exactly one dataset.** `unique_writer_identity = true` always — the project-wide shared logging account is never used — and the only grant is `roles/bigquery.dataEditor` on this dataset via `google_bigquery_dataset_iam_member`. Compromise of the sink identity cannot reach anything else.
- **Retention is partition expiration, not table expiration.** The sink streams into long-lived day-partitioned tables (`use_partitioned_tables = true`); a table-level expiration would eventually delete current data together with old data. Partition expiration ages out exactly one day at a time, which makes selective retention cheap (a metadata change, not a delete query).
- **`retention_years = 0` means forever, never "expire now".** Indefinite holds are a legitimate compliance posture; an accidental short expiration on an audit dataset is not, so there is no way to express one.
- **The default filter is intentionally narrow.** It matches structured audit log names rather than `ALL` logs, and an empty filter is rejected by validation — silently archiving every log line in the project is the classic way these datasets become the most expensive table in the org.
- **CMEK is optional, not mandatory.** Google-managed encryption is the default; teams with a key-custody requirement pass `kms_key_name` and the dataset picks it up as its default encryption configuration.
