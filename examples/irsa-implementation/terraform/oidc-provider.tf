# OIDC Provider Configuration for IRSA
# This example shows both EKS and kOps approaches for completeness

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# For EKS clusters (uncomment if using EKS)
# data "aws_eks_cluster" "cluster" {
#   name = var.cluster_name
# }

# For kOps clusters (recommended approach)
# Note: kOps manages the OIDC provider automatically when serviceAccountIssuerDiscovery is enabled
# This data source should be used after kOps cluster creation

# data "aws_iam_openid_connect_provider" "kops_oidc" {
#   # Uncomment and populate after kOps cluster creation
#   # arn = "arn:aws:iam::<account-id>:oidc-provider/<oidc-provider-url>"
# }

# For EKS: Get OIDC provider thumbprint
# data "tls_certificate" "cluster" {
#   url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# }

# For EKS: Create OIDC provider (kOps does this automatically)
# resource "aws_iam_openid_connect_provider" "cluster" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
#   url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
#
#   tags = {
#     Name        = "${var.cluster_name}-oidc-provider"
#     Environment = var.environment
#     ManagedBy   = "terraform"
#   }
# }

# Outputs (uncomment based on cluster type)

# For EKS clusters:
# output "oidc_provider_arn" {
#   description = "ARN of the OIDC provider"
#   value       = aws_iam_openid_connect_provider.cluster.arn
# }

# output "oidc_provider_url" {
#   description = "URL of the OIDC provider"
#   value       = aws_iam_openid_connect_provider.cluster.url
# }

# output "cluster_oidc_issuer_url" {
#   description = "OIDC issuer URL of the cluster"
#   value       = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# }

# For kOps clusters (OIDC provider managed by kOps):
output "kops_oidc_provider_arn" {
  description = "ARN of the kOps-managed OIDC provider (available after cluster creation)"
  value       = "OIDC provider ARN will be available after kOps cluster creation with serviceAccountIssuerDiscovery enabled"
}

output "kops_oidc_provider_url" {
  description = "URL of the kOps-managed OIDC provider (available after cluster creation)"
  value       = "OIDC provider URL will be available after kOps cluster creation with serviceAccountIssuerDiscovery enabled"
}