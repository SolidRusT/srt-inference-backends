resource "aws_s3_bucket" "scripts" {
  bucket = "${var.environment}-${var.name}-scripts-${var.region}"
  force_destroy = true
  
  tags = merge(var.tags, {
    Name = "${var.name}-scripts"
  })
}

resource "aws_s3_bucket_ownership_controls" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload utility scripts to S3
resource "aws_s3_object" "utility_scripts" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/utility-scripts.sh"
  content = templatefile("${path.module}/../ec2/templates/utility-scripts.sh.tpl", {
    aws_region              = var.aws_region
    app_port                = var.app_port
    vllm_port               = var.vllm_port
    ecr_repository_url      = var.ecr_repository_url
    hf_token_parameter_name = var.hf_token_parameter_name
    scripts_bucket          = aws_s3_bucket.scripts.id
  })
  content_type = "text/x-shellscript"
}

# Upload GPU setup script to S3
resource "aws_s3_object" "gpu_setup" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/gpu-setup.sh"
  content = templatefile("${path.module}/../ec2/templates/gpu-setup.sh.tpl", {})
  content_type = "text/x-shellscript"
}

# Upload services setup script to S3
resource "aws_s3_object" "services_setup" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/services-setup.sh"
  content = templatefile("${path.module}/../ec2/templates/services-setup.sh.tpl", {
    app_port                = var.app_port
    vllm_port               = var.vllm_port
    aws_region              = var.aws_region
    ecr_repository_url      = var.ecr_repository_url
    use_gpu                 = var.use_gpu
    model_id                = var.model_id
    max_model_len           = var.max_model_len
    gpu_memory_utilization  = var.gpu_memory_utilization
    vllm_image_tag          = var.vllm_image_tag
    enable_https            = var.enable_https
    tensor_parallel_size    = var.tensor_parallel_size
    pipeline_parallel_size  = var.pipeline_parallel_size
    tool_call_parser        = var.tool_call_parser
  })
  content_type = "text/x-shellscript"
}

# Upload NGINX setup script to S3
resource "aws_s3_object" "nginx_setup" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/nginx-setup.sh"
  content = templatefile("${path.module}/../ec2/templates/nginx-setup.sh.tpl", {
    app_port                = var.app_port
    domain_name             = var.domain_name
    admin_email             = var.admin_email
    default_proxy_timeout   = var.default_proxy_timeout
    max_proxy_timeout       = var.max_proxy_timeout
  })
  content_type = "text/x-shellscript"
}

# Upload main setup script to S3
resource "aws_s3_object" "main_setup" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/main-setup.sh"
  content = templatefile("${path.module}/../ec2/templates/main-setup.sh.tpl", {
    use_gpu                 = var.use_gpu
    enable_https            = var.enable_https
    instance_version        = var.instance_version
    aws_region              = var.aws_region
    scripts_bucket          = aws_s3_bucket.scripts.id
  })
  content_type = "text/x-shellscript"
}

# Upload watchdog script to S3
resource "aws_s3_object" "inference_watchdog" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/inference-watchdog.sh"
  content = templatefile("${path.module}/../ec2/templates/inference-watchdog.sh.tpl", {})
  content_type = "text/x-shellscript"
}

# Upload watchdog service file to S3
resource "aws_s3_object" "inference_watchdog_service" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/inference-watchdog.service"
  content = templatefile("${path.module}/../ec2/templates/inference-watchdog.service.tpl", {})
  content_type = "text/plain"
}

# Upload super force start script to S3
resource "aws_s3_object" "super_force_start" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/super-force-start.sh"
  content = templatefile("${path.module}/../ec2/templates/super-force-start.sh.tpl", {})
  content_type = "text/x-shellscript"
}

# Upload override services script to S3
resource "aws_s3_object" "override_services" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/override-services.sh"
  content = templatefile("${path.module}/../ec2/templates/override-services.sh.tpl", {})
  content_type = "text/x-shellscript"
}

# Upload manual start script to S3
resource "aws_s3_object" "manual_start" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/manual-start.sh"
  content = templatefile("${path.module}/../ec2/templates/manual-start.sh.tpl", {})
  content_type = "text/x-shellscript"
}