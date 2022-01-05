
terraform {
  backend "s3" {   # Name of the backend is s3
    bucket         = "ex-terraform-state-bucket"
    region         = "us-east-2"
    
    dynamodb_table = "ex-terraform-locks-table"
    encrypt        = true  # Additional check to ensure encryption on save.
			   # We have already enabled default encryption in the S3 bucket itself.
    key            = "golbal/s3/terraform.tfstate" # filepath within bucket where tfstate is stored.
						   # This will be different for each project,
						   # so it is kept here.
  }
}
