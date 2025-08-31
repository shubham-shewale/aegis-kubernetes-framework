# Generate unique bucket name with validation
locals {
  bucket_name = "${var.environment}-aegis-kops-state-${random_string.suffix.result}"
}

resource "aws_s3_bucket" "kops_state" {
  bucket = local.bucket_name

  tags = merge(
    {
      Name        = "${var.environment}-kops-state"
      Environment = var.environment
      Purpose     = "kops-cluster-state"
      Project     = "aegis-kubernetes-framework"
    },
    var.tags
  )
}

resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false

  # Ensure bucket name meets AWS requirements
  keepers = {
    environment = var.environment
    region      = var.region
  }
}

resource "aws_s3_bucket_versioning" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}