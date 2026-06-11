# gcp/network

Opinionated network foundation for a single-region GCP platform environment: a custom-mode VPC with one workload subnetwork, Private Services Access peering for managed services (Cloud SQL, Memorystore), Cloud NAT for controlled egress, and a default-deny ingress posture. It is the layer every other module in this catalog assumes exists -- compute attaches to the subnet, databases attach to the private services range, and nothing gets a public IP.

## Usage

```hcl
module "network" {
  source = "../../modules/gcp/network"

  name_prefix = "platform-prod"
  region      = "europe-west1"
  subnet_cidr = "10.10.0.0/20"

  # Optional: raise to 1.0 during an incident investigation window.
  flow_log_sampling = 0.5
}

module "database" {
  source = "../../modules/gcp/cloudsql"

  network_id                  = module.network.network_id
  private_services_range_name = module.network.private_services_range_name
  # ...
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name_prefix` | `string` | n/a | Prefix for all resource names. Max 20 chars, lowercase alphanumeric and hyphens. |
| `region` | `string` | n/a | GCP region for the subnetwork, router and NAT. |
| `subnet_cidr` | `string` | n/a | Primary IPv4 CIDR for the workload subnet. Validated as a parseable CIDR and rejected unless it is RFC 1918 space. |
| `flow_log_sampling` | `number` | `0.5` | VPC flow log sampling rate in (0, 1]. Zero (logs off) is deliberately not accepted. |

## Outputs

| Name | Description |
|------|-------------|
| `network_id` | Fully qualified VPC network ID. |
| `network_name` | VPC network name. |
| `subnet_id` | Fully qualified workload subnetwork ID. |
| `private_services_range_name` | Allocated Private Services Access range name, consumed by managed-service modules. |

## Opinions

- **Private by default.** Custom-mode VPC (`auto_create_subnetworks = false`) so no Google-managed subnets appear in regions nobody reviewed, plus an explicit deny-all ingress rule at priority 65534. Reaching a workload requires an intentional allow rule; nothing is reachable by omission.
- **NAT is the only road out.** Cloud NAT scoped to exactly this subnetwork gives workloads outbound internet access without ever holding a public IP. Subnets added later do not inherit egress silently -- they must be enrolled on purpose.
- **Flow logs from day one, priced sanely.** Flow logs cannot be disabled through this module (`flow_log_sampling > 0` is enforced), because the first time you need them is after the incident. 5-minute aggregation and 0.5 default sampling keep the cost honest; turn sampling up when investigating, not on permanently.
- **Managed services join the VPC, not the internet.** The /16 Private Services Access allocation and peering connection exist before any database does, so Cloud SQL and Memorystore land on private IPs as the path of least resistance. The /16 is sized up front because the range cannot be enlarged in place.
- **East-west traffic is scoped, not open.** The internal allow rule trusts only `subnet_cidr` -- not 10.0.0.0/8, not the whole VPC alias space. Peering another network in does not implicitly grant it lateral movement.
- **Regional routing.** `routing_mode = "REGIONAL"` keeps learned routes from propagating across regions; multi-region reachability is a decision to make explicitly, not a side effect.
- **Denied traffic is observable.** Firewall logging is enabled on the deny-all rule, so blocked connection attempts show up in Cloud Logging instead of vanishing.
