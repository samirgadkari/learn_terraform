# You cannot use the same state file to keep track of dev/staging/production.
# You can isolate state files using workspaces.
# By default, any changes you do go into the default workspace.
# Use these commands:
#   terraform workspace show   # to see which workspace youre using
#   terraform workspace new ex1 # to create ex1 workspace and start using it
#   terraform workspace select ex1 # to start using ex1 workspace
# You use workspaces when you have to test something quickly, but don't want to affect
# the dev/staging/production setup you already have. It allows you to create the exact
# same infrastructure, but store the state in a separate file.
# Drawbacks of using workspaces:
#   - Same authentication/access control for all workspaces, since all workspaces are stored
#     in the same backend
#   - You cannot see workspaces until you run terraform workspace commands. You cannot see the
#     workspace that is being used in any code files. Module deployed in one workspace look the
#     same as a module deployed in another.
#   - This makes workspaces error-prone. You can easily forget which workspace you were working on,
#     and make changes to the wrong workspace.

# Example of using workspaces:
provider "aws" {
  region = "us-east-2"
}

# The S3 bucket and the dynamodb table have already been created.
# We need to use a different key for the backend for this project.
terraform {
  backend "s3" {   # Name of the backend is s3
    # backend.hcl file parameters will be added here when you issue the command:
    # terraform init -backend-config=../backend.hcl
    key            = "workspaces-example/terraform.tfstate" # filepath within bucket where tfstate is stored.
						   # This will be different for each project,
						   # so it is kept here. filepath will be:
						   # bucketName/workspaceName/keyPath
  }
}

resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}

# Issue the commands:
#   terraform init -backend-config=./backend.hcl
#   terraform plan
#   terraform apply
#   terraform workspace show  # You see the default workspace. When you select the S3 bucket,
#			      # you will see workspaces-example has been created, and the
#			      # terraform.tfstate is stored under it.
#   terraform workspace new example1  # Create and switch to example1 workspace.
#				      # Switching to a different workspace switches the path
#				      # where the terraform state files is stored.
#   terraform plan
#   terraform apply
# When you select the S3 bucket, you will notice an env directory. This is created to store
# your workspaces, and example1 is in it.
#   terraform workspace new example2  # Create and switch to example2 workspace
#   terraform plan
#   terraform apply
# Now you will see example2 workspace. If you take a look at the EC2 instances, you will see
# there are 3 of them.
#   terraform workspace list   # Will show the list of workspaces, and put a * next to the one
#			       # you're on currently.
# Let's destroy all workspaces:
#   terraform destroy
#   terraform workspace select example1
#   terraform destroy
#   terraform workspace select default
#   terraform destroy
