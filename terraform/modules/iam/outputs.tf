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