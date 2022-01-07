
variable "server_port" {
  description = "The port used by the server for HTTP requests"
  type        = number
  default     = 8080
}

variable "alb_name" {
  description = "Name given to the ALB"
  type        = string
  default     = "terraform-asg-example"
}

variable "instance_security_group_name" {
  description = "Name of the EC2 instance's security group"
  type        = string
  default     = "terraform-example-instance"
}

variable "alb_security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "terraform-example-alb"
}

variable "db_remote_state_bucket" {
  description = "Name of the S3 bucket for remote state storage"
  type        = string
  default     = "ex-terraform-state-bucket"
}

variable "db_remote_state_key" {
  description = "Name of the key in the S3 bucket for remote state storage"
  type        = string
  default     = "stage/services/webserver-cluster/terraform.tfstate"
}





