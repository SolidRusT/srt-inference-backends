data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "inference-solution"
  })

  instance_name = "inference-${var.environment}"
  # Fixed timestamp to prevent unnecessary EC2 recreation
  deployment_timestamp = "2025-03-13"
}

# VPC and networking
module "vpc" {
  source = "./modules/vpc"
  name = "inference-solution"
  vpc_cidr      = var.vpc_cidr
  azs           = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  tags = local.tags
}

# ECR repository for storing Docker images
module "ecr" {
  source = "./modules/ecr"
  repository_name = "inference-app-${var.environment}"
  tags           = local.tags
}

# S3 bucket for scripts
module "scripts_bucket" {
  source = "./modules/scripts_bucket"
  name           = "inference-scripts"
  environment    = var.environment
  region         = var.region
  aws_region     = var.region
  app_port       = var.app_port
  vllm_port      = var.vllm_port
  ecr_repository_url = module.ecr.repository_url
  hf_token_parameter_name = var.hf_token_parameter_name
  use_gpu       = var.use_gpu_instance
  model_id      = var.model_id
  max_model_len = var.max_model_len
  gpu_memory_utilization = var.gpu_memory_utilization
  vllm_image_tag = var.vllm_image_tag
  enable_https  = var.enable_https && var.create_route53_records
  domain_name   = var.domain_name
  admin_email   = var.email_address
  default_proxy_timeout = var.default_proxy_timeout
  max_proxy_timeout = var.max_proxy_timeout
  tensor_parallel_size = var.tensor_parallel_size
  pipeline_parallel_size = var.pipeline_parallel_size
  tool_call_parser = var.tool_call_parser
  instance_version = var.ec2_instance_version
  tags          = local.tags

  depends_on = [module.ecr]
}

# EC2 instance for running the inference application
module "ec2" {
  source = "./modules/ec2"
  name              = local.instance_name
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnets[0]  # Use first public subnet
  instance_type     = var.instance_type
  use_gpu           = var.use_gpu_instance
  gpu_instance_type = var.gpu_instance_type
  key_name          = var.key_name
  app_port          = var.app_port
  vllm_port         = var.vllm_port
  model_id          = var.model_id
  max_model_len     = var.max_model_len
  gpu_memory_utilization = var.gpu_memory_utilization
  tensor_parallel_size = var.tensor_parallel_size
  pipeline_parallel_size = var.pipeline_parallel_size
  tool_call_parser   = var.tool_call_parser
  vllm_image_tag    = var.vllm_image_tag
  hf_token_parameter_name = var.hf_token_parameter_name
  region            = var.region
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ecr_repository_url = module.ecr.repository_url
  enable_https      = var.enable_https && var.create_route53_records
  certificate_arn   = ""
  domain_name       = var.domain_name
  admin_email       = var.email_address
  user_data_timestamp = local.deployment_timestamp
  instance_version  = var.ec2_instance_version  # Pass through the instance version
  root_volume_size  = var.root_volume_size
  default_proxy_timeout = var.default_proxy_timeout
  max_proxy_timeout = var.max_proxy_timeout
  scripts_bucket    = module.scripts_bucket.bucket_name
  main_setup_key    = module.scripts_bucket.main_setup_key
  tags              = local.tags
}

# Build and push the Docker image
module "build" {
  source = "./modules/build"
  ecr_repository_url = module.ecr.repository_url
  aws_region         = var.region

  depends_on = [module.ecr]
}

# DNS configuration
module "route53" {
  source = "./modules/route53"
  count  = var.create_route53_records ? 1 : 0
  domain_name         = var.domain_name
  instance_public_ip  = module.ec2.instance_public_ip
  create_example_record = true
  # Use a known zone_id if available to avoid replacement
  zone_id             = var.route53_zone_id

  depends_on = [module.ec2]
}

# Set ECR policy for the EC2 instance
resource "aws_ecr_repository_policy" "inference_app_policy" {
  repository = module.ecr.repository_name
  policy     = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowPull",
        Effect = "Allow",
        Principal = {
          "AWS": module.ec2.instance_role_arn
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })

  depends_on = [module.ecr, module.ec2]
}