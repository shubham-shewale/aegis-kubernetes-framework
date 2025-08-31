output "kops_state_bucket_name" {
  description = "Name of the S3 bucket for kops state"
  value       = aws_s3_bucket.kops_state.bucket
}

output "kops_state_bucket_arn" {
  description = "ARN of the S3 bucket for kops state"
  value       = aws_s3_bucket.kops_state.arn
}