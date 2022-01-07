
# To see the S3 bucket and table terraform is using:
output "s3_bucket_arn" {
  value       = aws_s3_bucket.ex-terraform-state-bucket.arn
  description = "ARN of the S3 bucket"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table name"
}
