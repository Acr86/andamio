variable "name" {
  type        = string
  description = "Repository id. Becomes part of the image URL, so keep it short and stable (e.g. \"platform-images\")."

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.name)) && length(var.name) <= 63
    error_message = "Repository name must be 1-63 characters, lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "location" {
  type        = string
  description = "Region or multi-region for the repository (e.g. \"europe-west1\" or \"us\"). Determines the registry host: <location>-docker.pkg.dev."

  validation {
    condition     = can(regex("^[a-z]+(-[a-z]+[0-9])?$", var.location))
    error_message = "Location must be a GCP region (e.g. \"europe-west1\") or multi-region (e.g. \"us\", \"europe\")."
  }
}

variable "project_id" {
  type        = string
  description = "Project that owns the repository."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project id must be 6-30 characters, lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "description" {
  type        = string
  description = "What this repository holds and which delivery pipeline feeds it. Required on purpose: undocumented registries accumulate orphans nobody dares to delete."

  validation {
    condition     = length(trimspace(var.description)) > 0
    error_message = "Description must not be empty. State what the repository holds and who pushes to it."
  }
}

variable "untagged_retention_days" {
  type        = number
  description = "Days an untagged image digest survives before automatic deletion. Untagged digests are almost always superseded layers left behind by retagging."
  default     = 7

  validation {
    condition     = var.untagged_retention_days >= 1 && var.untagged_retention_days <= 365 && floor(var.untagged_retention_days) == var.untagged_retention_days
    error_message = "untagged_retention_days must be a whole number between 1 and 365."
  }
}

variable "keep_tagged_count" {
  type        = number
  description = "Number of most recent versions that are always kept, regardless of any delete policy. Size this to the rollback horizon: how many releases back you realistically redeploy."
  default     = 20

  validation {
    condition     = var.keep_tagged_count >= 1 && var.keep_tagged_count <= 1000 && floor(var.keep_tagged_count) == var.keep_tagged_count
    error_message = "keep_tagged_count must be a whole number between 1 and 1000."
  }
}

variable "kms_key_name" {
  type        = string
  description = "Full resource name of a Cloud KMS key for CMEK encryption (projects/.../locations/.../keyRings/.../cryptoKeys/...). Leave null to use Google-managed encryption."
  default     = null

  validation {
    condition     = var.kms_key_name == null || can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.kms_key_name))
    error_message = "kms_key_name must be a full Cloud KMS key resource name: projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>."
  }
}
