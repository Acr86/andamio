resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = var.name
  display_name = "Runtime identity for ${var.name}"
  description  = "Dedicated per-workload identity. This module grants it nothing; callers attach resource-scoped roles to the exported email."
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region
  ingress  = var.ingress

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = var.network_id
        subnetwork = var.subnet_id
      }
    }

    containers {
      image = var.image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }
    }
  }

  lifecycle {
    # Build-once/promote ownership split: CI builds an immutable digest and
    # promotes that exact digest through environments by updating the service
    # directly. Terraform owns every other runtime attribute. Without this,
    # each promotion shows up as drift and a later `terraform apply` would
    # silently roll the service back to the stale bootstrap image.
    ignore_changes = [template[0].containers[0].image]
  }
}

resource "google_cloud_run_v2_job" "this" {
  count = var.enable_job ? 1 : 0

  project  = var.project_id
  name     = "${var.name}-job"
  location = var.region

  template {
    template {
      service_account = google_service_account.runtime.email
      timeout         = var.job_timeout
      max_retries     = var.job_max_retries

      vpc_access {
        egress = "PRIVATE_RANGES_ONLY"

        network_interfaces {
          network    = var.network_id
          subnetwork = var.subnet_id
        }
      }

      containers {
        image   = var.image
        command = length(var.job_command) > 0 ? var.job_command : null
        args    = length(var.job_args) > 0 ? var.job_args : null

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    # Same ownership split as the service: CI updates the job image when it
    # promotes a release, so the job always migrates with the code it ships.
    ignore_changes = [template[0].template[0].containers[0].image]
  }
}
