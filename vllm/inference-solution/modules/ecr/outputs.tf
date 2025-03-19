output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.inference_app.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.inference_app.name
}

output "registry_id" {
  description = "Registry ID"
  value       = aws_ecr_repository.inference_app.registry_id
}
