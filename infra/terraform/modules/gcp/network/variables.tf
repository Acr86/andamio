variable "name_prefix" {
  type        = string
  description = "Prefix applied to every resource name in this module (e.g. \"platform-prod\"). Lowercase letters, digits and hyphens; must start with a letter."

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,18}[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix must match ^[a-z]([a-z0-9-]{0,18}[a-z0-9])?$ (max 20 chars, leaving room for resource-name suffixes within GCP's 63-char limit)."
  }
}

variable "region" {
  type        = string
  description = "GCP region for the subnetwork, router and NAT (e.g. \"europe-west1\")."

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must be a valid GCP region identifier such as \"us-central1\" or \"europe-west4\"."
  }
}

variable "subnet_cidr" {
  type        = string
  description = "Primary IPv4 CIDR range for the workload subnetwork. Must be RFC 1918 address space."

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0)) && can(regex("/(\\d{1,2})$", var.subnet_cidr))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block, e.g. \"10.10.0.0/20\"."
  }

  validation {
    condition     = can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)", var.subnet_cidr))
    error_message = "subnet_cidr must be RFC 1918 private address space (10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16)."
  }
}

variable "flow_log_sampling" {
  type        = number
  description = "VPC flow log sampling rate for the subnetwork, in (0, 1]. 1.0 captures every flow; 0.5 halves logging cost while keeping statistically useful coverage."
  default     = 0.5

  validation {
    condition     = var.flow_log_sampling > 0 && var.flow_log_sampling <= 1
    error_message = "flow_log_sampling must be greater than 0 and at most 1. Disabling flow logs is not supported by this module."
  }
}
