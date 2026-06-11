# gcp/registry

Artifact Registry Docker repository with FinOps cleanup baked in. Every repository created
through this module garbage-collects untagged image digests automatically and guarantees a
fixed rollback horizon of recent versions that no delete policy can touch. Encryption defaults
to Google-managed keys with an optional CMEK switch for workloads that require customer-held
key material.

## Usage

```hcl
module "registry" {
  source = "../../modules/gcp/registry"

  name        = "platform-images"
  location    = "europe-west1"
  project_id  = "platform-delivery-prod"
  description = "Service images built by the platform CI pipeline; pushed on merge to main."

  untagged_retention_days = 7
  keep_tagged_count       = 20

  # Optional CMEK; omit (null) for Google-managed encryption.
  kms_key_name = "projects/platform-delivery-prod/locations/europe-west1/keyRings/delivery/cryptoKeys/registry"
}

# Push: docker push <module.registry.repository_url>/api:1.4.2
```

## Opinions

- **Storage is not free.** Every CI rebuild that retags `:main` orphans the previous digest.
  Left alone, a busy repository grows by gigabytes per week of layers nobody can name. Untagged
  digests are deleted automatically after `untagged_retention_days` (default 7) — long enough to
  debug "what did CI just overwrite", short enough that the bill never notices.
- **Keep window sized to the rollback horizon.** The `KEEP most_recent_versions` policy (default
  20) is a hard floor: in Artifact Registry, KEEP always beats DELETE, so the most recent
  versions survive any cleanup policy added later. Set `keep_tagged_count` to the number of
  releases you would realistically redeploy — not to "everything, forever".
- **Tag immutability is OFF, deliberately.** Deployments must promote by digest
  (`image@sha256:...`), which makes tag immutability far less load-bearing: a moving tag never
  decides what runs in an environment. Immutable tags would break the cheap, useful convention
  of retagging `:stable` after a canary passes, while buying integrity that digest pinning
  already provides. If a deploy pipeline resolves tags at deploy time, fix the pipeline, not
  the registry.
- **Cleanup policies enforce, they do not advise.** `cleanup_policy_dry_run` is hardcoded to
  `false`. A dry-run policy is a dashboard nobody reads; flip it temporarily in a fork only
  when auditing a policy change against an already-populated repository.
- **`description` is required.** An undocumented registry becomes the place where orphaned
  images accumulate because nobody dares to delete what nobody can explain. The module refuses
  an empty description.
- **CMEK is a switch, not a fork.** `kms_key_name = null` means Google-managed encryption;
  passing a full KMS key resource name enables CMEK on the same module. No parallel
  "regulated" variant to keep in sync.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | — | Repository id; becomes part of the image URL. |
| `location` | `string` | — | Region or multi-region; determines `<location>-docker.pkg.dev`. |
| `project_id` | `string` | — | Project that owns the repository. |
| `description` | `string` | — | What the repository holds and which pipeline feeds it. |
| `untagged_retention_days` | `number` | `7` | Days an untagged digest survives before deletion. |
| `keep_tagged_count` | `number` | `20` | Most recent versions always kept (rollback horizon). |
| `kms_key_name` | `string` | `null` | Full Cloud KMS key resource name for CMEK; null = Google-managed. |

## Outputs

| Name | Description |
|------|-------------|
| `repository_id` | Fully qualified repository id, for IAM bindings. |
| `repository_url` | Docker registry URL to push to and pull from. |
