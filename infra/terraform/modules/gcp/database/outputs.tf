output "instance_connection_name" {
  description = "Connection name (PROJECT:REGION:INSTANCE) consumed by the Cloud SQL connectors and the auth proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = google_sql_database_instance.this.name
}

output "private_ip_address" {
  description = "Private IP address of the instance inside the VPC. The only address it has."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Name of the logical database created on the instance."
  value       = google_sql_database.this.name
}
