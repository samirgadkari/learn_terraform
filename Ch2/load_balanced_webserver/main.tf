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

# Security settings for all EC2 instances in the group.
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

# The aws_launch_configuration uses almost the same information as the aws_instance, except:
#   ami -> image_id
#   vpc_security_groups_id -> security_groups
#
resource "aws_launch_configuration" "example" {
  image_id = "ami-0c55b159cbfafe1f0"    # This AMI is for ubuntu. This AMI is only available on
					# us-east-2.
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id] # reference the aws_security_group
                                                     # resource created above. Terraform creates
                                                     # resources that have no references first,
                                                     # and then those that have references.
                                                     # "terraform graph" shows the dependency graph.
                                                     # Use Graphviz to display it.
  # We pass a shell script to User Data by setting the user_data argument
  # in our terraform code.
  # In our case, this causes the script code to run.
  # You cannot have comments between the <<-EOF and EOF below, if you're interpolating
  # variables using $ sign. This is why we moved these comments before the user_data
  # section.
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
}

# To look up the default VPC, subnet data, or AMI IDs, you can use a data source.
# ex: to look up default VPC
data "aws_vpc" "default" {
  default = true  # Filter that indicates which specific VPC you want
}
# You can use this VPC with data.aws_vpc.default.id for the VPC id.

# To use this to get subnet IDs in the default VPC id:
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id # Filter that indicates which specific 
				   # subnet IDs you want using VPC's id.
}
# Now you can use the data.aws_subnet_ids.default.ids to get a list of subnets
# within the default VPC.

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# By default, the load balancer does not allow any incoming/outgoing traffic.
# Create a security group to allow ingress/egress traffic, and tell the
# aws_lb to use this security group.
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  # Allow inbound HTTP requests
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0    # from any port
    to_port     = 0    # to any port
    protocol    = "-1" # any protocol allowed
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AWS's Elastic Load Balancer (ELB) service has 3 types of load balancers:
#   - Application load balancer (ALB) for Layer 7 (HTTP/HTTPS) traffic
#   - Network load balancer (NLB) for Layer 4 (TCP/UDP/TLS) traffic. It scales to
#     tens of millions of requests per second, and responds to varying loads faster than ALB.
#   - Classic load balancer (CLB) is the legacy load balancer with Layer 4 and Layer 7 support,
#     but with far fewer features. Usually this is not used.
# Our webserver is Layer 7, so we will use ALB. For the ALB, you specify:
#   - Listener: Port to listen to (ex. 80), and protocol to listen for (ex. HTTP)
#   - Listener rules: Which incoming urls are forwarded to which target groups
#   - Target groups: Servers that receive requests from the load balancer. The target group
#     also performs health checks, and sends requests to only healthy nodes.
# AWS automatically does the load balancing and handles failover by bringing up a new server,
# if a server goes down.
resource "aws_lb" "example" {
  name                = "terraform-asg-example"
  load_balancer_type  = "application"

  # These default subnet IDs are IDs of all subnets (thus all Availability Zones - AZ.
  # Each AZ is in a different datacenter). This allows us to run our workloads even if
  # there is an outage in one datacenter.
  subnets             = data.aws_subnet_ids.default.ids

  security_groups     = [aws_security_group.alb.id]
}

# The aws_lb_listener forwards the packets to a target group.
# Each service must have a target group. A target is the server that handles the request.
# A target server can belong to multiple target groups.
# Targets are specified by CIDR blocks, instance ID, or ARN.
# One other way of specifying targets, is to use the aws_autoscaling_group.target_group_arns,
# and list this aws_lb_target_group.asg.arn in that list.
resource "aws_lb_target_group" "asg" {
  name    = "terraform-asg-example"
  port    = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"        # default is "EC2" which fails only if the VM is down/unreachable.
				   # "ELB" informs the ASG to use the target groups' health check.
				   # This causes instances to be reported unhealthy if they
				   # ran out of memory, or a critical process crashed.

  min_size = 2
  max_size = 10

  tag {
    key		       = "Name"
    value              = "terraform-asg-example"
    propagate_at_launch = true     # propagates this tag to instances launched via this ASG.
  }
  
  # Required when using a launch configuration with an auto scaling group.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    # If anything changes in the launch_caonfiguration, and you run terraform apply,
    # Terraform will try to replace it. To do so, it will first remove the old launch config.
    # But aws_autoscaling_group has a reference to the launch_configuration,
    # so it cannot delete it.
    # By setting create_before_destroy = true, Terraform:
    #   - creates a new aws_launch_configuration resource
    #   - creates a new aws_autoscaling_group resource, and sets it to point to the new
    #     aws_launch_configuration resource it just created.
    #   - destroys the old aws_launch_configuration, and the old aws_autoscaling_group resources.
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values     = ["*"]
    }
  }

  # If the condition above is met for the incoming request,
  # it will be redirected to the target group shown in the action section.

  action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.asg.arn
  }
}

output "alb_dns_name" {            # All output variables are printed out at the end of the
				   # terraform apply command output.
				   # You can also issue the "terraform output" command to see
				   # these variables, or "terraform output alb_dns_name" to see
				   # a specific variable.
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
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
