# IAM Roles for Service Accounts (IRSA)
# This creates IAM roles that can be assumed by Kubernetes service accounts

# Data source for OIDC provider
data "aws_iam_openid_connect_provider" "cluster" {
  arn = aws_iam_openid_connect_provider.cluster.arn
}

# S3 Access Role
resource "aws_iam_role" "s3_access" {
  name = "${var.cluster_name}-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:s3-access-sa"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-s3-access-role"
    Environment = var.environment
    Purpose     = "IRSA-S3-Access"
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# DynamoDB Access Role
resource "aws_iam_role" "dynamodb_access" {
  name = "${var.cluster_name}-dynamodb-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:dynamodb-access-sa"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-dynamodb-access-role"
    Environment = var.environment
    Purpose     = "IRSA-DynamoDB-Access"
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.dynamodb_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}

# CloudWatch Logs Access Role
resource "aws_iam_role" "cloudwatch_access" {
  name = "${var.cluster_name}-cloudwatch-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:cloudwatch-access-sa"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-cloudwatch-access-role"
    Environment = var.environment
    Purpose     = "IRSA-CloudWatch-Access"
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.cloudwatch_access.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Custom Policy Example - S3 Full Access with restrictions
resource "aws_iam_role" "s3_full_access" {
  name = "${var.cluster_name}-s3-full-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:default:s3-full-access-sa"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-s3-full-access-role"
    Environment = var.environment
    Purpose     = "IRSA-S3-Full-Access"
  })
}

resource "aws_iam_policy" "s3_full_access_restricted" {
  name        = "${var.cluster_name}-s3-full-access-restricted"
  description = "Restricted S3 full access policy for IRSA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.cluster_name}-app-data",
          "arn:aws:s3:::${var.cluster_name}-app-data/*"
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-s3-full-access-restricted"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "s3_full_access_restricted" {
  role       = aws_iam_role.s3_full_access.name
  policy_arn = aws_iam_policy.s3_full_access_restricted.arn
}

# Multi-namespace role (can be used by service accounts in any namespace)
resource "aws_iam_role" "multi_namespace_s3" {
  name = "${var.cluster_name}-multi-namespace-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringLike = {
            "${aws_iam_openid_connect_provider.cluster.url}:sub": "system:serviceaccount:*:multi-namespace-sa"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-multi-namespace-s3-role"
    Environment = var.environment
    Purpose     = "IRSA-Multi-Namespace"
  })
}

resource "aws_iam_role_policy_attachment" "multi_namespace_s3" {
  role       = aws_iam_role.multi_namespace_s3.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Outputs
output "s3_access_role_arn" {
  description = "ARN of the S3 access IAM role"
  value       = aws_iam_role.s3_access.arn
}

output "dynamodb_access_role_arn" {
  description = "ARN of the DynamoDB access IAM role"
  value       = aws_iam_role.dynamodb_access.arn
}

output "cloudwatch_access_role_arn" {
  description = "ARN of the CloudWatch access IAM role"
  value       = aws_iam_role.cloudwatch_access.arn
}

output "s3_full_access_role_arn" {
  description = "ARN of the S3 full access IAM role"
  value       = aws_iam_role.s3_full_access.arn
}

output "multi_namespace_s3_role_arn" {
  description = "ARN of the multi-namespace S3 access IAM role"
  value       = aws_iam_role.multi_namespace_s3.arn
}