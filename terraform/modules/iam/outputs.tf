output "kops_role_arn" {
  description = "ARN of kops IAM role"
  value       = aws_iam_role.kops.arn
}

output "nodes_role_arn" {
  description = "ARN of Kubernetes nodes IAM role"
  value       = aws_iam_role.nodes.arn
}

output "nodes_instance_profile_name" {
  description = "Name of nodes instance profile"
  value       = aws_iam_instance_profile.nodes.name
}

output "oidc_provider_arn" {
  description = "ARN of the kOps-managed OIDC provider (available after cluster creation)"
  value       = "OIDC provider ARN will be available after kOps cluster creation with serviceAccountIssuerDiscovery enabled"
}

output "oidc_provider_url" {
  description = "URL of the kOps-managed OIDC provider (available after cluster creation)"
  value       = "OIDC provider URL will be available after kOps cluster creation with serviceAccountIssuerDiscovery enabled"
}