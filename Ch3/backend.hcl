# Pass this file in using:
#   terraform init -backend-config=backend.hcl
# These parameters are added to the 
#   terraform {
#     backend "s3" {
#       # these parameters are added here
#     }
#   }
# The backend.hcl file should be moved into a directory like "common",
# so that users will know that this file data is used in more than one place.
bucket         = "ex-terraform-state-bucket"
region         = "us-east-2"

dynamodb_table = "ex-terraform-locks-table"
encrypt        = true  # Additional check to ensure encryption on save.
		   # We have already enabled default encryption in the S3 bucket itself.
