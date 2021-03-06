
provider "aws" {
  region = "us-east-2"  # AMI images in this book are based on us-east-2,
                        # so we will just use us-east-2.
}

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
  user_data = data.template_file.user_data.rendered

  # Required when using a launch configuration with an auto scaling group.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}

# The template_file data source has two arguments:
#   template: string to render
#   vars:     map of variables you can use to render string
data "template_file" "user_data" {
  template = file("user-data.sh")
  vars = {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
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

resource "aws_lb" "example" {
  name                = var.alb_name
  load_balancer_type  = "application"

  # These default subnet IDs are IDs of all subnets (thus all Availability Zones - AZ.
  # Each AZ is in a different datacenter). This allows us to run our workloads even if
  # there is an outage in one datacenter.
  subnets             = data.aws_subnet_ids.default.ids

  security_groups     = [aws_security_group.alb.id]
}

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

resource "aws_lb_target_group" "asg" {
  name    = var.alb_name
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

resource "aws_security_group" "alb" {
  name = var.alb_security_group_name

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

# terraform_remote_state can only get read-only access to data.
# All of the database's output variables are stored in the state file,
# and you can read them from the terraform_remote_state using
#   data.terraform_remote_state.db.<NAME>.outputs.<ATTRIBUTE>
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}

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

terraform {
  backend "s3" {   # Name of the backend is s3
    bucket         = "ex-terraform-state-bucket" # terraform init gives variables cannot be used here for: var.db_remote_state_bucket
    region         = "us-east-2"
    
    dynamodb_table = "ex-terraform-locks-table"
    encrypt        = true  # Additional check to ensure encryption on save.
			   # We have already enabled default encryption in the S3 bucket itself.
    key            = "stage/services/webserver-cluster/terraform.tfstate" # terraform init gives variables cannot be used here for: var.db_remote_state_key 
						   # filepath within bucket where tfstate is stored.
						   # This will be different for each project,
						   # so it is kept here.
  }
}

# Terraform contains many built-in functions you can use.
# A great way to try this out is to run
#   terraform console
#   format("%.3f", 3.14159)
# terraform console is read-only, so you don't have to worry about breaking your configuration.

