output "bucket_name" {
  description = "Name of the scripts bucket"
  value       = aws_s3_bucket.scripts.id
}

output "bucket_arn" {
  description = "ARN of the scripts bucket"
  value       = aws_s3_bucket.scripts.arn
}

output "scripts_base_path" {
  description = "Base path for scripts in the bucket"
  value       = "scripts/"
}

output "main_setup_key" {
  description = "S3 key for the main setup script"
  value       = aws_s3_object.main_setup.key
}