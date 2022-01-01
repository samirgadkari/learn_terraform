provider "aws" {
  region = "us-east-2"  # AMI images in this book are based on us-east-2,
                        # so we will just use us-east-2.
}

# For each provider, there are many different kind of resources, specified as:
# resource "PROVIDER_TYPE" "NAME" {
#   CONFIG
# }

variable "server_port" {
  description = "The port used by the server for HTTP requests"
  type        = number
  default     = 8080
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  # By default, AWS does not allow any incoming/outgoing traffic from an EC2 instance.
  # This new security group called "aws_security_group" speficies that
  # AWS should allow incoming/outgoing TCP traffic on port 8080
  # limited to the IP addr range 0.0.0.0/0 (all possible IP addresses given in a CIDR block format).
  # 10.0.0.0/24 is all IP addresses between 10.0.0.0 and 10.0.0.255 (high 24 bits fixed).
  ingress {
    from_port = var.server_port  # We use 8080 instead of port 80 for HTTP because any port less than 1024
    to_port   = var.server_port  # requires root user privileges. If an attacker compromisses your server,
				 # they will get root access too.
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami = "ami-0c55b159cbfafe1f0"    # This AMI is for ubuntu. This AMI is only available on
				   # us-east-2.
  # We pass a shell script to User Data by setting the user_data argument
  # in our terraform code.
  # In our case, this causes the script code to run.
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id] # reference the aws_security_group
                                                            # resource created above. Terraform creates
                                                            # resources that have no references first,
                                                            # and then those that have references.
                                                            # "terraform graph" shows the dependency graph.
                                                            # Use Graphviz to display it.
  
  # busybox provides a suite of unix utilities, including httpd, the web server.
  # user_data points to the shell script to run after instance boots up.
  # nohup command & causes command to run forever, in the background.
  # Since we're running in the background, -f flag tells the webserver
  # to not daemonize. This way, the bash script ends, but the server keeps running.
  # The web server is listening to port 8080, since that is what server_port is configured to.
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html  
              nohup busybox httpd -f -p "${var.server_port}" &  
              EOF

  tags = {
    Name = "terraform-example"
  }
}

output "public_ip" {               # All output variables are printed out at the end of the
				   # terraform apply command output.
				   # You can also issue the "terraform output" command to see
				   # these variables, or "terraform output public_ip" to see
				   # a specific variable.
  value       = aws_instance.example.public_ip
  description = "Public IP address of the web server"
}

output "server_port" {
  value       = var.server_port
  description = "Server port number to access web server"
}

# We deployed these resources in the default VPC, and the default subnets of that VPC.
# Each VPC is partitioned into one or more subnets. The subnets in the default VPC are all
# public subnets. This is why we can connect to our EC2 instance from any laptop.
# This is a security vulnerability. We should never deploy our production resources on a
# public subnet.
#
# For production, we should create a private VPC and subnets within it. These IP addresses
# can then be accessible from within the same VPC. The only servers that should be accessible
# from public IP addresses are the load balancers. These you should run in a public subnet
# and lock down as much as possible.

# Creating variables and referencing them:
# ex:
# variable "number_example" {
#   description = "......"
#   type        = number  # Possible types: string, number, bool, list, map, set, object, tuple, any.
#			  # You can also have list(number) type (ex. [1, 2, 3]), or
#			  # map(string) type (ex. {key1 = "a", key2 = "b"}), or
#			  # object({name = string, age = number{) type (ex. {name = "a", age = 2}).
#   default     = 42      # You can pass in the variable on the command line using -var.
#			  # Pass via a file using -var-file on the command line.
#			  # Pass via an environment variable using TF_VAR_<variable_name>.
#			  # If no value passed in, the default given here is used.
# }
# The types you can create are: string, number, bool, list, map, set, object, tuple, any.
# If not specified, type is assumed to be any.
