# Terraform Backend Configuration
# This file should be modified per environment before running terraform init
# For initial setup, comment out the backend block and run terraform init
# Then uncomment and run terraform init again to migrate state

terraform {
  backend "s3" {
    # These values should be updated per environment
    bucket = "aegis-terraform-state-staging"  # Update for your environment
    key    = "aegis/terraform.tfstate"
    region = "us-east-1"  # Update for your region

    # Optional: Enable encryption and versioning
    encrypt = true

    # Optional: DynamoDB table for state locking (recommended for team environments)
    # dynamodb_table = "aegis-terraform-locks"
  }
}