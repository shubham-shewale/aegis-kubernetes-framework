# OIDC Provider Configuration for IRSA
# This sets up the OpenID Connect provider for IAM Roles for Service Accounts

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Get cluster OIDC issuer URL
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Get OIDC provider thumbprint
data "tls_certificate" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# Create OIDC provider for the cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.cluster_name}-oidc-provider"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Output the OIDC provider ARN for use in IAM roles
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.oidc_provider.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_iam_openid_connect_provider.oidc_provider.url
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster"
  value       = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}