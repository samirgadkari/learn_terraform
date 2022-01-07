provider "aws" {
  region = "us-east-2"
}

resource "aws_db_instance" "example" {
  identifier_prefix    = "terraform-up-and-running"
  engine               = "mysql"
  allocated_storage    = 10
  instance_class       = "db.t2.micro"
  name                 = "example_database"

  username             = local.db_creds.username
  password             = local.db_creds.password

  # Required to get around a bug in AWS
  skip_final_snapshot = true
}

terraform {
  backend "s3" {   # Name of the backend is s3
    bucket         = "ex-terraform-state-bucket"
    region         = "us-east-2"
    
    dynamodb_table = "ex-terraform-locks-table"
    encrypt        = true  # Additional check to ensure encryption on save.
			   # We have already enabled default encryption in the S3 bucket itself.
    key            = "stage/data-stores/mysql/terraform.tfstate" # filepath within bucket where tfstate is stored.
						   # This will be different for each project,
						   # so it is kept here.
  }
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "mysql_master_pwd_stage"
}

locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

