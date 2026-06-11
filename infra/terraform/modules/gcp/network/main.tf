resource "google_compute_network" "this" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  # REGIONAL keeps dynamic routes from leaking across regions; widen deliberately, not by default.
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name                     = "${var.name_prefix}-${var.region}"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  log_config {
    # 5-minute aggregation instead of the 5-second default: same forensic value, a fraction of the cost.
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling        = var.flow_log_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Services Access: an allocated range peered to Google's service producer
# network so Cloud SQL / Memorystore get private IPs instead of public endpoints.
resource "google_compute_global_address" "private_services" {
  name         = "${var.name_prefix}-psa-range"
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"
  network      = google_compute_network.this.id
  # /16 leaves headroom for multiple managed-service instances; Google recommends
  # at least /24 per producer and the range cannot be grown in place later.
  prefix_length = 16
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "google_compute_router" "this" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name   = "${var.name_prefix}-nat"
  region = var.region
  router = google_compute_router.this.name

  nat_ip_allocate_option = "AUTO_ONLY"

  # NAT is scoped to the workload subnet only; new subnets do not get egress for free.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.this.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    # ERRORS_ONLY surfaces port-exhaustion and dropped connections without per-flow log volume.
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.name_prefix}-deny-all-ingress"
  network = google_compute_network.this.id

  direction = "INGRESS"
  # 65534 sits just above the implied rules: any intentional allow at the default
  # priority (1000) wins, but nothing reaches a VM by accident.
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.this.id

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }
}
