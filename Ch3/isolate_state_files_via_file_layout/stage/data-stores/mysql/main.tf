provider "aws" {
  region = "us-east-2"
}

resource "aws_db_instance" "example" {
  identifier_prefix    = "terraform-up-and-running"
  engine               = "mysql"
  allocated_storage    = 10
  instance_class       = "db.t2.micro"
  name                 = "example_database"
  username             = "admin"

  # password             = "1053099tickets"
  password             = data.aws_secretsmanager_secret_version.db_password.secret_string

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

# Uncomment out the password = "1053..." above. Comment out the password = data.aws...
# Comment out the aws_secretsmanager_secret_version.db_password below.
# Run terraform init and terraform apply to create the database above.
# Then go into the AWS secrets manager, and create a secret for this database.
# Then uncomment the code below, and the password commented out in the above aws_db_instance.
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "mysql_master_password_stage"
}
