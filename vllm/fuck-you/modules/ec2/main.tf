data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM policy for S3 scripts access
resource "aws_iam_policy" "s3_scripts_access" {
  name        = "${var.name}-s3-scripts-access"
  description = "Policy for S3 scripts access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.scripts_bucket}",
          "arn:aws:s3:::${var.scripts_bucket}/*"
        ]
      }
    ]
  })
}

# Security group for EC2 instance
resource "aws_security_group" "inference_instance" {
  name        = "${var.name}-sg"
  description = "Security group for inference instance"
  vpc_id      = var.vpc_id

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTP to API proxy"
  }

  # Allow HTTP without API proxy
  ingress {
    from_port   = var.vllm_port
    to_port     = var.vllm_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTP to vLLM"
  }

  # Allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTPS to API proxy"
  }

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH to instance"
  }

  # Allow API port
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "API proxy port"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

# IAM role for EC2 instance
resource "aws_iam_role" "inference_instance" {
  name = "${var.name}-role"
  force_detach_policies = true

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for ECR access
resource "aws_iam_policy" "ecr_access" {
  name        = "${var.name}-ecr-access"
  description = "Policy for ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM policy for SSM Parameter access (for HF token)
resource "aws_iam_policy" "ssm_parameter_access" {
  name        = "${var.name}-ssm-parameter-access"
  description = "Policy for SSM Parameter access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:ssm:${var.region}:*:parameter${var.hf_token_parameter_name}",
          "arn:aws:ssm:${var.region}:*:parameter/inference/*"
        ]
      }
    ]
  })
}

# Attach ECR access policy to role
resource "aws_iam_role_policy_attachment" "ecr_access_attach" {
  role       = aws_iam_role.inference_instance.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

# Attach S3 scripts access policy
resource "aws_iam_role_policy_attachment" "s3_scripts_access_attach" {
  role       = aws_iam_role.inference_instance.name
  policy_arn = aws_iam_policy.s3_scripts_access.arn
}

# Attach SSM parameter access policy
resource "aws_iam_role_policy_attachment" "ssm_parameter_access_attach" {
  role       = aws_iam_role.inference_instance.name
  policy_arn = aws_iam_policy.ssm_parameter_access.arn
}

# Attach SSM policy for easier management
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.inference_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "inference_instance" {
  name = "${var.name}-profile"
  role = aws_iam_role.inference_instance.name
}

# Create bootstrap script for user data
locals {
  user_data = templatefile("${path.module}/templates/bootstrap.sh.tpl", {
    instance_version = var.instance_version
    aws_region       = var.region
    scripts_bucket   = var.scripts_bucket
    main_setup_key   = var.main_setup_key
    use_gpu          = tostring(var.use_gpu)
  })
}

# EC2 instance
resource "aws_instance" "inference" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.use_gpu ? var.gpu_instance_type : var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.inference_instance.id]
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.inference_instance.name
  user_data              = local.user_data
  # Not replacing EC2 instance on user data change for better idempotency
  user_data_replace_on_change = false
  
  # Tag with version to track the deployment version
  tags = merge(var.tags, { 
    Name = var.name, 
    Version = var.instance_version 
  })

  # This is a special attribute that forces replacement when instance_version changes
  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [null_resource.instance_version_trigger.id]
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2
  }

  # Connect to session manager instead of direct SSH
  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} has been created. Connect using AWS SSM Session Manager.'"
  }
}

# Null resource to trigger instance replacement based on version
resource "null_resource" "instance_version_trigger" {
  triggers = {
    instance_version = var.instance_version
  }
}

# Elastic IP for the instance
resource "aws_eip" "inference" {
  domain   = "vpc"
  instance = aws_instance.inference.id
  tags     = merge(var.tags, { Name = "${var.name}-eip" })
}