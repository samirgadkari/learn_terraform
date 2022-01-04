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

resource "aws_s3_bucket" "terraform_state" {
  bucket = "ex-terraform-state-bucket"  # this must be unique across ALL S3 users
  
  # Prevent accidental destruction of this bucket with "terraform destroy".
  # To really delete this bucket, comment this out and then run "terraform destroy".
  lifecycle {
    prevent_destroy = true
  }

  # Enable versioning of the state file, so we can rollback to any version
  versioning {
    enabled = true
  }

  # Enable server-side encryption by default for all data in this bucket.
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Create a DynamoDB table for locking. DynamoDB is AWS key-value store.
# To use it for terraform, create a table with primary key LockID (exact spelling/capitalization).
resource "aws_dynamodb_table" "terraform_locks" {
  name            = "ex-terraform-locks-table"
  billing_mode    = "PAY_PER_REQUEST"
  hash_key        = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}

# Run terraform init, and terraform apply. This creates the above resources.
# After that, your still have to tell terraform to use the remote backend
# to store state. So do this:
#
terraform {
  backend "s3" {   # Name of the backend is s3
    # backend.hcl file parameters will be added here when you issue the command:
    # terraform init -backend-config=backend.hcl
    key            = "golbal/s3/terraform.tfstate" # filepath within bucket where tfstate is stored.
						   # This will be different for each project,
						   # so it is kept here.
  }
}

# Now run terraform init again. This will cause terraform to save state in your S3 bucket.
# terraform init now:
#   - downloads provider code that it needs
#   - configures terraform backend.

# To see the S3 bucket and table terraform is using:
output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "ARN of the S3 bucket"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table name"
}

# Limitations of backends is that to create the backend:
#   - add the code to add bucket and dynamodb table first,
#   - issue terraform init, terraform apply to create the bucket/dynamodb using local
#     terraform.tfstate file.
#   - add a remote backend in the code, and apply the terraform init command to copy the
#     local terraform.tfstate file to the S3 bucket.
# Once the bucket and table exist, you can start adding code to create the backend.
# You should use a different backend path for different projects.
# To destroy everything, do this sequence in reverse:
#   - Remove the backend config in *.tf files, apply the terraform init command to copy the
#     remote backend terraform.tfstate to your local disk
#   - Run terraform destroy to delete the S3 bucket and dynamodb table.

# The backend block in terraform does not allow you to use any variables or references.
# Instead, use the partial configuration (omit certain parameters from the backend config block,
# and pass a file path (backend.hcl) to those parameters on the command line for terraform init).

