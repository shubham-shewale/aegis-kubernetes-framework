output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "kops_state_bucket" {
  description = "Name of kops state bucket"
  value       = module.s3.kops_state_bucket_name
}

output "kops_role_arn" {
  description = "ARN of kops IAM role"
  value       = module.iam.kops_role_arn
}

output "nodes_instance_profile" {
  description = "Name of nodes instance profile"
  value       = module.iam.nodes_instance_profile_name
}