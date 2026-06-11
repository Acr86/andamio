variable "name_prefix" {
  type        = string
  description = "Prefix for all identity resources (pool, provider, service account). Lowercase letters, digits, hyphens."

  validation {
    # Longest derived id is "<prefix>-github-oidc" (pool/provider ids max 32 chars)
    # and the service account id "<prefix>-deploy" must stay within 6-30 chars.
    condition     = can(regex("^[a-z][a-z0-9-]{0,18}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 2-20 chars, start with a letter, end with a letter or digit, and contain only lowercase letters, digits, and hyphens."
  }

  validation {
    condition     = !startswith(var.name_prefix, "gcp")
    error_message = "name_prefix must not start with \"gcp\": workload identity pool ids prefixed with gcp- are reserved by Google."
  }
}

variable "project_id" {
  type        = string
  description = "GCP project that hosts the workload identity pool and the deploy service account."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project id (6-30 chars, lowercase letters, digits, hyphens, starting with a letter)."
  }
}

variable "github_repository" {
  type        = string
  description = "GitHub repository allowed to impersonate the deploy service account, in owner/name form (e.g. acme/platform)."

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be in owner/name form, e.g. acme/platform."
  }
}

variable "allowed_refs" {
  type        = list(string)
  description = "Fully qualified git refs allowed to exchange tokens (e.g. refs/heads/main, refs/tags/v1.2.3). Anything else, including pull_request refs, is denied."
  default     = ["refs/heads/main"]

  validation {
    condition     = length(var.allowed_refs) > 0
    error_message = "allowed_refs must contain at least one ref; an empty list would deny all token exchanges."
  }

  validation {
    condition     = alltrue([for r in var.allowed_refs : can(regex("^refs/(heads|tags)/.+$", r))])
    error_message = "Every entry in allowed_refs must be a fully qualified branch or tag ref (refs/heads/* or refs/tags/*)."
  }
}
