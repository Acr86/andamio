# gcp/cicd-identity

Keyless CI/CD identity for GitHub Actions on GCP. Creates a workload identity pool and an OIDC provider trusting `https://token.actions.githubusercontent.com`, pinned to exactly one repository and an explicit list of git refs, plus a deploy service account that GitHub Actions impersonates through short-lived federated tokens. No service account keys are created, exported, or needed anywhere in the pipeline.

## Usage

```hcl
module "cicd_identity" {
  source = "../../modules/gcp/cicd-identity"

  name_prefix       = "platform"
  project_id        = "platform-prod-123456"
  github_repository = "acme/platform"
  allowed_refs      = ["refs/heads/main"] # exact match only, no globs; see Opinions
}

# Resource-scoped grant, defined next to the resource it protects:
resource "google_cloud_run_v2_service_iam_member" "deployer" {
  name   = google_cloud_run_v2_service.api.name
  role   = "roles/run.developer"
  member = "serviceAccount:${module.cicd_identity.deploy_service_account_email}"
}
```

In the workflow:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${{ vars.WORKLOAD_IDENTITY_PROVIDER }} # workload_identity_provider output
      service_account: ${{ vars.DEPLOY_SA_EMAIL }}                       # deploy_service_account_email output
```

## Opinions

- **Zero long-lived keys.** There is no `google_service_account_key` in this module and there never will be. Exported JSON keys are an unexpirable credential sitting in CI secrets; OIDC federation replaces them with tokens that live minutes and are minted only for a workflow run that satisfies the trust condition.
- **Trust is narrowed to one repository AND named refs, at the provider.** The `attribute_condition` (`assertion.repository == "owner/name" && assertion.ref in [...]`) is enforced by Google STS at token exchange. A workflow on a fork, another repo in the same org, a feature branch, or a `pull_request` event (whose ref is `refs/pull/...`) is rejected before any IAM evaluation happens. One pool+provider per repository, not a shared org-wide pool with per-binding filtering.
- **The repository pin is enforced twice.** The `roles/iam.workloadIdentityUser` binding uses `principalSet://.../attribute.repository/<repo>` rather than the whole pool, so even a later relaxation of the provider condition does not silently widen who can impersonate the deploy SA.
- **The deploy SA gets no project roles here.** This module outputs `deploy_service_account_email` and nothing else binds it. Grants belong next to the resources being deployed (a specific Cloud Run service, a specific Artifact Registry repository), keeping the blast radius of a compromised pipeline readable from the resource's own module.
- **`assertion.ref` is not the same as a protected ref — document it, don't pretend.** Pinning `refs/heads/main` means anyone who can push to `main` can deploy; the claim proves which ref ran, not that the ref is protected. Pair this module with GitHub branch protection (or rulesets) on every ref listed in `allowed_refs`. If you need GCP-side enforcement of protection itself, map `assertion.ref_protected` and extend the condition with `assertion.ref_protected == "true"`.
- **`allowed_refs` is exact-match by design.** The CEL `in` operator does no globbing, so `refs/tags/v*` only matches a tag literally named `v*`. This is deliberate: an explicit allowlist of deployable refs beats a wildcard nobody audits. If a team truly needs pattern-matched tags, that is a conscious edit to the condition (`assertion.ref.startsWith(...)`), not a default.
