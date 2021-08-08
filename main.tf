provider "aws" {
  region = "us-east-2"
}

# For each provider, there are many different kind of resources, specified as:
# resource "PROVIDER_TYPE" "NAME" {
#   CONFIG
# }
resource "aws_instance" "example" {
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}

