# gcp/database — Cloud SQL for PostgreSQL

Provisions a Cloud SQL PostgreSQL 17 instance reachable only over private IP inside an existing VPC, plus one logical database. The module bakes in the platform's recovery and access posture — IAM database authentication, automated backups with point-in-time recovery, query insights, session-lifecycle audit logging — so consumers only choose sizing, HA, and retention. It deliberately does not expose any knob that would weaken that posture.

## Dependency: private services access

`private_network` requires an active service networking connection (private services access) on the VPC. The `network` module creates it. Terraform cannot infer this ordering from the `network_id` string, so either pass an output that is derived from the connection or add an explicit `depends_on` on the network module. Creating the instance before the peering exists fails with a service networking error.

## Usage

```hcl
module "database" {
  source = "../../modules/gcp/database"

  name          = "platform-pg-prod"
  region        = "europe-west1"
  network_id    = module.network.network_id
  database_name = "orders"

  tier                  = "db-custom-2-7680"
  ha                    = true
  backup_retention_days = 14

  maintenance_window_day  = 7
  maintenance_window_hour = 3

  labels = {
    environment = "prod"
    team        = "platform"
  }

  depends_on = [module.network]
}
```

## Inputs

| Name | Default | Purpose |
|---|---|---|
| `name` | — | Instance name |
| `region` | — | GCP region |
| `network_id` | — | Fully qualified VPC network id |
| `database_name` | — | Logical database to create |
| `tier` | `db-custom-1-3840` | Machine shape |
| `ha` | `false` | `true` = REGIONAL, `false` = ZONAL |
| `backup_retention_days` | `7` | Retained automated backups |
| `pitr` | `true` | Point-in-time recovery |
| `deletion_protection` | `true` | Block accidental destroy |
| `maintenance_window_day` | `7` | 1 = Monday ... 7 = Sunday |
| `maintenance_window_hour` | `3` | Hour of day, UTC |
| `labels` | `{}` | Cost attribution labels |

## Outputs

`instance_connection_name`, `instance_name`, `private_ip_address`, `database_name`.

## Opinions

- **No public IP exists as an option.** `ipv4_enabled` is hardcoded to `false`; there is no variable to flip it. A database that can be exposed by a one-line tfvars change will eventually be exposed. Access paths are the VPC and the Cloud SQL auth proxy through it.
- **IAM database authentication over passwords.** `cloudsql.iam_authentication` is always on. Service accounts authenticate with short-lived tokens tied to IAM; there is no long-lived database password to rotate, leak, or commit.
- **PITR on by default.** Restores are a product feature, not a heroic act. Point-in-time recovery and daily backups are the default state; turning PITR off is an explicit, reviewable decision for disposable data only.
- **TLS even inside the VPC.** `ssl_mode = "ENCRYPTED_ONLY"` — a private network is a smaller blast radius, not a trust boundary.
- **Session logging yes, statement logging no.** Connections, disconnections, checkpoints, and lock waits are logged for audit and incident timelines, but `log_min_duration_statement = -1` because SQL text can embed row data; query performance questions go to Query Insights instead, which also never records client addresses.
- **HA is a boolean, not a copy-paste.** `ha = true` flips to REGIONAL with automatic failover; pre-production stays ZONAL and costs half. Same module, same posture, one switch between environments.
- **`deletion_protection` defaults to true.** Destroying the instance requires a deliberate two-step change, which is exactly the amount of friction a stateful resource deserves.
- **Maintenance on the `stable` track in a fixed window.** Default Sunday 03:00 UTC: predictable patching beats surprise patching, and off-peak beats peak.
