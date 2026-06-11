locals {
  # The subject claim encodes repo and ref in one assertion
  # (repo:OWNER/NAME:ref:REF) — pinning sub directly is the canonical GitHub
  # OIDC hardening. The repository/ref assertions are kept as a second,
  # independent layer of the same pin. jsonencode produces valid CEL string
  # literals, which sidesteps hand-rolled quote escaping.
  github_sub_condition = join(" || ", formatlist(
    "assertion.sub == \"repo:%s:ref:%s\"",
    var.github_repository,
    var.allowed_refs,
  ))
  github_attribute_condition = format(
    "(%s) && assertion.repository == %s && assertion.ref in %s",
    local.github_sub_condition,
    jsonencode(var.github_repository),
    jsonencode(var.allowed_refs),
  )
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.name_prefix}-github-pool"
  display_name              = "${var.name_prefix} GitHub Actions"
  description               = "Federated identities for GitHub Actions CI/CD. No service account keys exist for this path."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  # checkov:skip=CKV_GCP_125:The attribute_condition DOES pin assertion.sub to repo:<repo>:ref:<ref> for every allowed ref (built in locals via formatlist), plus repository and ref assertions. Checkov's static renderer cannot evaluate the function call, so it cannot see the literal it requires.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.name_prefix}-github-oidc"
  display_name                       = "GitHub Actions OIDC"
  description                        = "Trusts ${var.github_repository} on ${join(", ", var.allowed_refs)} only."

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.ref"              = "assertion.ref"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Enforced at token exchange: a stolen workflow on any other repo or ref
  # never gets a federated token, regardless of downstream IAM bindings.
  attribute_condition = local.github_attribute_condition
}

resource "google_service_account" "deploy" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-deploy"
  display_name = "${var.name_prefix} CI/CD deploy"
  description  = "Impersonated by GitHub Actions via workload identity federation. Grant roles on individual resources, never project-wide."
}

resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  # Second layer of the same pin: even if the provider condition were relaxed,
  # this binding only matches identities whose mapped repository attribute
  # equals the configured repo.
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
