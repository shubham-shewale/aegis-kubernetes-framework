variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1, eu-west-1)."
  }
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production", "development"], var.environment)
    error_message = "Environment must be one of: staging, production, development."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && can(cidrnetmask(var.vpc_cidr))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 3
    error_message = "Must specify between 2 and 3 availability zones."
  }
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  validation {
    condition = alltrue([
      for cidr in var.public_subnets : can(cidrhost(cidr, 0)) && can(cidrnetmask(cidr))
    ])
    error_message = "All public subnet CIDRs must be valid CIDR blocks."
  }
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition = alltrue([
      for cidr in var.private_subnets : can(cidrhost(cidr, 0)) && can(cidrnetmask(cidr))
    ])
    error_message = "All private subnet CIDRs must be valid CIDR blocks."
  }
}

variable "state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = ""

  validation {
    condition     = var.state_bucket == "" || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.state_bucket))
    error_message = "State bucket name must be a valid S3 bucket name (lowercase, no underscores)."
  }
}

variable "cluster_name" {
  description = "Name of the kOps cluster"
  type        = string
  default     = "aegis-cluster"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}

variable "oidc_thumbprint" {
  description = "OIDC provider thumbprint from kOps cluster"
  type        = string
  default     = ""

  validation {
    condition     = var.oidc_thumbprint == "" || can(regex("^[A-Fa-f0-9]{40}$", var.oidc_thumbprint))
    error_message = "OIDC thumbprint must be a valid SHA1 fingerprint (40 hex characters)."
  }
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.tags :
      can(regex("^[a-zA-Z0-9_.:/=+-@]{1,128}$", key)) &&
      can(regex("^[a-zA-Z0-9_.:/=+-@]{0,256}$", value))
    ])
    error_message = "Tag keys and values must follow AWS tagging restrictions."
  }
}