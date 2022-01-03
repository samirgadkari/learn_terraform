# Terraform know which infrastructure in AWS it is responsible for by looking at the
# terraform.tfstate file. This file contains a mapping from:
#    *.tf files in your dir <---> actual infrastructure created in AWS
# This file is created when you run terraform commands.
# The output of terraform plan is the diff between this file and the infrastructure in AWS.
# You should never manually edit this file.
# When working on the same infrastructure with a team, this can cause problems like
#   - you need shared storage for this file  - a locking mechanism
# Terraform state should not be stored in version control because:
#   - need to remember to pull before making changes
#   - terraform apply can be run by many users at the same time, with different configurations
#   - secrets are stored unencrypted in the terraform.tfstate file
# Instead, use remote backends. When specified, terraform pulls terraform.tfstate from the
# backend, runs it's command, and then saves the result back to the backend.
# S3 backend has
#   - locking support
#   - IAM policies so only specific uses can access specific tfstate files
#   - Secrets are also encrypted in-flight and at rest with S3
#   - Each file change can be saved as a separate version, so you can rollback
#   - Inexpensive
# Example of how to do this:

provider "aws" {
  region = "us-east-2"
}


