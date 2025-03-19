resource "aws_ecr_repository" "inference_app" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Set repository policy for pulling images
resource "aws_ecr_repository_policy" "inference_app_policy" {
  count      = var.instance_role_arn != "" ? 1 : 0
  repository = aws_ecr_repository.inference_app.name
  policy     = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowPull",
        Effect = "Allow",
        Principal = {
          "AWS": var.instance_role_arn
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# Lifecycle policy to keep only the latest N images
resource "aws_ecr_lifecycle_policy" "inference_app_lifecycle" {
  repository = aws_ecr_repository.inference_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 5 images",
        selection = {
          tagStatus     = "any",
          countType     = "imageCountMoreThan",
          countNumber   = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
