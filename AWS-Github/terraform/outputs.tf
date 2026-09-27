output "aws_role_arn" {
  description = "IAM Role ARN for GitHub Actions OIDC — Add this to GitHub Secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API Server Endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security Group ID of the EKS Cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC IAM Provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "update_kubeconfig_command" {
  description = "Run this command locally to connect kubectl to your newly created EKS cluster"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
}
