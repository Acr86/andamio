resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.name
  description   = var.description
  format        = "DOCKER"

  kms_key_name = var.kms_key_name

  docker_config {
    # Deliberately mutable: deployments promote by digest, so a moving tag
    # never decides what runs. Locking tags would only break the
    # "retag :stable after canary" workflow. Rationale in README.
    immutable_tags = false
  }

  # Policies enforce, they do not advise. Flip to true only while auditing
  # a policy change against a populated repository.
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state = "UNTAGGED"
      # The API expects a duration in seconds.
      older_than = "${var.untagged_retention_days * 24 * 60 * 60}s"
    }
  }

  # KEEP always wins over DELETE in Artifact Registry cleanup, so this acts
  # as a hard floor: the most recent versions survive any delete policy
  # added later, preserving the rollback horizon.
  cleanup_policies {
    id     = "keep-rollback-horizon"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_tagged_count
    }
  }
}
