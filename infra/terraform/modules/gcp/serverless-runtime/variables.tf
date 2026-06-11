variable "project_id" {
  type        = string
  description = "GCP project that hosts the service, job, and service account."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 chars, lowercase letters, digits, hyphens)."
  }
}

variable "region" {
  type        = string
  description = "Region for the Cloud Run service and job (e.g. europe-west1)."

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region must be a valid GCP region name such as europe-west1 or us-central1."
  }
}

variable "name" {
  type        = string
  description = "Workload name. Used as the Cloud Run service name and as the service account ID, so it must satisfy both."

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.name)) && length(var.name) >= 6 && length(var.name) <= 30
    error_message = "name must be 6-30 chars, lowercase letters, digits, and hyphens, starting with a letter; the 30-char cap comes from the service account ID limit."
  }
}

variable "image" {
  type        = string
  description = "Bootstrap container image used on first apply only. After creation the image is owned by the CI pipeline and ignored by Terraform."

  validation {
    condition     = length(var.image) > 0 && !endswith(var.image, ":latest")
    error_message = "image must be set and pinned to an explicit tag or digest; :latest is not reproducible or auditable."
  }
}

variable "container_port" {
  type        = number
  description = "Port the container listens on. Cloud Run injects it as the PORT env var."
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "ingress" {
  type        = string
  description = "Ingress policy for the service. Defaults to internal-load-balancer only; widening it is a deliberate caller decision."
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.ingress)
    error_message = "ingress must be one of INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "network_id" {
  type        = string
  description = "VPC network (self link or ID) for direct VPC egress."

  validation {
    condition     = length(var.network_id) > 0
    error_message = "network_id must not be empty."
  }
}

variable "subnet_id" {
  type        = string
  description = "Subnetwork (self link or ID) for direct VPC egress. Must be in the same region as the service."

  validation {
    condition     = length(var.subnet_id) > 0
    error_message = "subnet_id must not be empty."
  }
}

variable "min_instances" {
  type        = number
  description = "Minimum number of instances kept warm. 0 allows scale-to-zero."
  default     = 0

  validation {
    condition     = var.min_instances >= 0
    error_message = "min_instances must be zero or positive."
  }
}

variable "max_instances" {
  type        = number
  description = "Upper bound on instances. Acts as the blast-radius and cost ceiling."
  default     = 10

  validation {
    condition     = var.max_instances >= 1
    error_message = "max_instances must be at least 1."
  }

  validation {
    condition     = var.max_instances >= var.min_instances
    error_message = "max_instances must be greater than or equal to min_instances."
  }
}

variable "env" {
  type        = map(string)
  description = "Plaintext environment variables. Never put secrets here; use secret_env."
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.env) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))])
    error_message = "env keys must be valid environment variable names ([A-Za-z_][A-Za-z0-9_]*)."
  }

  validation {
    condition     = length(setintersection(toset(keys(var.env)), toset(["PORT", "K_SERVICE", "K_REVISION", "K_CONFIGURATION"]))) == 0
    error_message = "PORT, K_SERVICE, K_REVISION, and K_CONFIGURATION are reserved by Cloud Run and must not be set."
  }
}

variable "secret_env" {
  type = map(object({
    secret  = string
    version = optional(string, "latest")
  }))
  description = "Environment variables sourced from Secret Manager, keyed by env var name. secret is a Secret Manager secret ID or full resource name; version defaults to latest."
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.secret_env) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))])
    error_message = "secret_env keys must be valid environment variable names ([A-Za-z_][A-Za-z0-9_]*)."
  }

  validation {
    condition     = alltrue([for s in values(var.secret_env) : length(s.secret) > 0])
    error_message = "Every secret_env entry must reference a non-empty Secret Manager secret."
  }

  validation {
    condition     = length(setintersection(toset(keys(var.env)), toset(keys(var.secret_env)))) == 0
    error_message = "env and secret_env must not define the same variable name."
  }
}

variable "cpu_limit" {
  type        = string
  description = "CPU limit per instance, in Kubernetes quantity form (e.g. \"1\", \"2\", \"500m\")."
  default     = "1"

  validation {
    condition     = can(regex("^([0-9]+m|[0-9]+(\\.[0-9]+)?)$", var.cpu_limit))
    error_message = "cpu_limit must be a CPU quantity such as \"1\", \"2\", \"0.5\", or \"500m\"."
  }
}

variable "memory_limit" {
  type        = string
  description = "Memory limit per instance (e.g. \"512Mi\", \"1Gi\")."
  default     = "512Mi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi)$", var.memory_limit))
    error_message = "memory_limit must be expressed in Mi or Gi, e.g. \"512Mi\" or \"1Gi\"."
  }
}

variable "enable_job" {
  type        = bool
  description = "Create a companion Cloud Run job (same image, identity, and network), typically for database migrations."
  default     = false
}

variable "job_command" {
  type        = list(string)
  description = "Container entrypoint override for the job. Empty list keeps the image's default entrypoint."
  default     = []
}

variable "job_args" {
  type        = list(string)
  description = "Arguments passed to the job's entrypoint. Empty list keeps the image's defaults."
  default     = []
}

variable "job_timeout" {
  type        = string
  description = "Per-attempt deadline for the job, in seconds with the \"s\" suffix."
  default     = "600s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.job_timeout))
    error_message = "job_timeout must be a duration in seconds, e.g. \"600s\"."
  }
}

variable "job_max_retries" {
  type        = number
  description = "Automatic retries per job task. Defaults to 0: a failed migration needs a human, not a blind re-run."
  default     = 0

  validation {
    condition     = var.job_max_retries >= 0 && var.job_max_retries <= 10
    error_message = "job_max_retries must be between 0 and 10."
  }
}
