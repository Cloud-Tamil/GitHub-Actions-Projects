output "gcp_workload_identity_provider" {
  description = "The Workload Identity Provider resource name — Add to GitHub Secrets as GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "gcp_service_account" {
  description = "The Service Account email for GitHub Actions — Add to GitHub Secrets as GCP_SERVICE_ACCOUNT"
  value       = google_service_account.github_actions.email
}

output "cluster_name" {
  description = "GKE Cluster Name"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "GKE Cluster Location / Region"
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "GKE API Server Endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = false
}

output "get_credentials_command" {
  description = "Command to configure kubectl locally with GKE cluster credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.gcp_region} --project ${var.project_id}"
}
