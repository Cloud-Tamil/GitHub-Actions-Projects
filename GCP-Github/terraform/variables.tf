variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
  default     = "qwiklabs-gcp-02-6d090168dd30" # Replace with your actual GCP Project ID
}

variable "gcp_region" {
  description = "The Google Cloud region for GKE and networking"
  type        = string
  default     = " 	us-east1"
}

variable "cluster_name" {
  description = "GKE cluster name (matches cd.yml: task-manager-cluster)"
  type        = string
  default     = "task-manager-cluster"
}

variable "github_repo" {
  description = "GitHub repository allowed to authenticate via Workload Identity (Format: OWNER/REPO)"
  type        = string
  default     = "Cloud-Tamil/GitHub-Actions"
}

variable "environment" {
  description = "Environment name (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary GKE subnet"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR block for GKE pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR block for GKE services"
  type        = string
  default     = "10.30.0.0/20"
}

variable "node_machine_type" {
  description = "Compute Engine machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "node_desired_count" {
  description = "Desired number of worker nodes per zone/region"
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 4
}
