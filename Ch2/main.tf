provider "aws" {
  region = "us-east-2"  # AMI images in this book are based on us-east-2,
                        # so we will just use us-east-2.
}

# For each provider, there are many different kind of resources, specified as:
# resource "PROVIDER_TYPE" "NAME" {
#   CONFIG
# }

## Example 1.
#resource "aws_instance" "example" {
#  ami = "ami-0c55b159cbfafe1f0"
#  instance_type = "t2.micro"
#}

## Example 2.
#resource "aws-instance" "example" {
#  ami = "ami-0c55b159cbfafe1f0"
#  instance_type = "t2.micro"
#
#  # We pass a shell script to User Data by setting the user_data argument
#  # in our terraform code.
#  # In our case, this causes the script code to run.
#  user_data = <<-EOF
#              #!/bin/bash
#              echo "Hello, World" > index.html  # index.html file has "Hello, World" in it now.
#              nohup busybox httpd -f -p 8080 &  # nohup command & causes command to run forever,
#						 # whereas the bash script can exit.
#                                                # busybox provides a suite of unix utilities,
#                                                # including httpd, the web server.
#						 # -f tells busybox not to daemonize, since
#						 # we're running in background using &.
#                                                # The web server is listening to port 8080.
#              EOF
#
#  tags = {
#    Name = "terraform-example"   # Add a name to this EC2 instance.
#  }
#}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  # By default, AWS does not allow any incoming/outgoing traffic from an EC2 instance.
  # This new security group called "aws_security_group" speficies that
  # AWS should allow incoming/outgoing TCP traffic on port 8080
  # limited to the IP addr range 0.0.0.0/0 (all possible IP addresses given in a CIDR block format).
  # 10.0.0.0/24 is all IP addresses between 10.0.0.0 and 10.0.0.255 (high 24 bits fixed).
  ingress {
    from_port = 8080  # We use 8080 instead of port 80 for HTTP because any port less than 1024
    to_port   = 8080  # requires root user privileges. If an attacker compromisses your server,
		      # they will get root access too.
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami = "ami-0c55b159cbfafe1f0"    # This AMI is for ubuntu. This AMI is only available on
				   # us-east-2.
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id] # reference the aws_security_group
                                                            # resource created above. Terraform creates
                                                            # resources that have no references first,
                                                            # and then those that have references.
                                                            # "terraform graph" shows the dependency graph.
                                                            # Use Graphviz to display it.
  
  # user_data points to the shell script to run after instance boots up.
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html  # index.html file has "Hello, World" in it now.
              nohup busybox httpd -f -p 8080 &  # nohup command & causes command to run forever.
                                                # busybox provides a suite of unix utilities,
                                                # including httpd, the web server.
                                                # The web server is listening to port 8080.
              EOF

  tags = {
    Name = "terraform-example"
  }
}

