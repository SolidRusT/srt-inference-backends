variable "ecr_repository_url" {
  description = "URL of the ECR repository where the image will be pushed"
  type        = string
}

variable "aws_region" {
  description = "AWS region for ECR"
  type        = string
}
