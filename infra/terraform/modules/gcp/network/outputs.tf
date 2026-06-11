output "network_id" {
  description = "Fully qualified ID of the VPC network."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the VPC network."
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "Fully qualified ID of the workload subnetwork."
  value       = google_compute_subnetwork.this.id
}

output "private_services_range_name" {
  description = "Name of the allocated Private Services Access range; pass to managed services (Cloud SQL, Memorystore) that attach via private IP."
  value       = google_compute_global_address.private_services.name
}
