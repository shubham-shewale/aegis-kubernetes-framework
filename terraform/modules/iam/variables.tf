variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the kOps cluster"
  type        = string
}

variable "oidc_thumbprint" {
  description = "OIDC provider thumbprint from kOps"
  type        = string
  default     = ""
}

variable "kops_state_bucket" {
  description = "kOps state S3 bucket name"
  type        = string
}