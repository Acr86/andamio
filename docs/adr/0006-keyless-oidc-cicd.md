# 0006. Keyless OIDC for CI/CD identity

Date: 2026-06

## Status

Accepted

## Context

CI needs to authenticate to clouds (Terraform plan/apply, future deploys) and to sign images. The traditional answer is a service-account key or access key pair stored as a CI secret. Every such key is a standing credential: it works from anywhere, for anyone holding it, until someone rotates it. Exfiltration through a compromised action, a leaked log, or an over-scoped runner is the dominant CI attack story, and rotation schedules only shrink the window — they never close it. The same applies to signing: a stored cosign private key is one more secret whose compromise silently breaks the supply chain.

## Decision

No long-lived cloud or signing keys exist anywhere in the platform. GitHub Actions authenticates with short-lived OIDC tokens, exchanged for cloud credentials at the provider:

- **GCP** ([modules/gcp/cicd-identity](../../infra/terraform/modules/gcp/cicd-identity/main.tf)): a Workload Identity Federation pool and provider whose `attribute_condition` requires `assertion.repository == <repo>` and `assertion.ref in <allowed refs>`. The check runs at token exchange — a stolen workflow on any other repository or ref never obtains a credential. The service-account binding additionally matches on the mapped repository attribute.
- **AWS** ([modules/aws/cicd-identity](../../infra/terraform/modules/aws/cicd-identity/main.tf)): an IAM OIDC provider plus a role whose trust policy pins `sub` to the repository and refs. The genuine delta from GCP is where trust lives — AWS evaluates it per role, GCP at the pool/provider — which is why the two modules are not mirror copies and the difference is worth reading.

Image signing uses the same identity: cosign keyless signing exchanges the workflow's OIDC token for a short-lived certificate, so a signature attests "this exact workflow, on this repo and ref, signed this digest" — no signing key to store, rotate, or lose.

Both modules are part of the validated-but-never-deployed Terraform blueprint; the trust topology is exercised by `terraform validate`, tflint, and checkov in CI.

## Alternatives considered

**Stored service-account keys with 90-day rotation.** The conventional hardening. Rejected for two reasons. First, rotation is recurring toil with a failure mode: the rotation that does not happen, or happens and breaks the pipeline at the worst moment. Second — and decisive — rotation does not change what the credential is. A key valid for 90 days is a bearer secret usable from any machine on earth for 90 days; cloud audit logs cannot distinguish CI from a thief replaying the key. An OIDC-federated credential is minted per job, expires in minutes, and is bound to a workflow identity the cloud can verify and log.

## Consequences

- The CI provider's OIDC issuer becomes part of the cloud trust boundary. A compromise or token-misissuance incident at GitHub is no longer a source-control incident — it is a cloud-trust incident across every environment that federates with it, and there is no key to rotate your way out; the response is breaking federation. Accepted mitigations: repository and ref pinning enforced at token exchange, short session lifetimes, and separate identities per environment so staging trust never reaches prod. Because the trust is declared in Terraform, severing it is a single apply.
- Break-glass is harder by design. There is no key to hand a human during an outage; emergency access must go through human IAM identities, not the CI path. That friction is the point, but it must be planned for rather than discovered mid-incident.
- Keyless cosign ties signature verification to the Sigstore public-good infrastructure (Fulcio, Rekor) — an external availability and trust dependency the platform does not control.
