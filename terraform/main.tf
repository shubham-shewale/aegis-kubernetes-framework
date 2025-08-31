terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Backend configuration moved to separate file for better state management
# See backend.tf for state configuration

provider "aws" {
  region = var.region

  # Security best practices
  default_tags {
    tags = {
      Project     = "aegis-kubernetes-framework"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  environment        = var.environment
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  environment = var.environment
  region      = var.region
}

# S3 Module for kops state
module "s3" {
  source = "./modules/s3"

  environment = var.environment
  region      = var.region
  tags        = var.tags
}