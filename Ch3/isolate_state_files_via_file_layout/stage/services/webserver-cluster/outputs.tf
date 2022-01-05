
output "alb_dns_name" {            # All output variables are printed out at the end of the
				   # terraform apply command output.
				   # You can also issue the "terraform output" command to see
				   # these variables, or "terraform output alb_dns_name" to see
				   # a specific variable.
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}


