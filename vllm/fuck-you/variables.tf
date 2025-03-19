variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name for the cluster"
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "rancher-platform"
  }
}

variable "domain_name" {
  description = "Domain name for platform components"
  type        = string
  default     = "live.ca.obenv.net"
}

variable "create_route53_records" {
  description = "Whether to create Route53 records (requires domain to exist)"
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "Route53 zone ID (if known to avoid lookups)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "email_address" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}

variable "allowed_cidr_blocks" {
  description = "List of CIDRs that can access the load balancer endpoints (e.g. your office or home IP)"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type for the inference server"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 30
}

variable "use_gpu_instance" {
  description = "Whether to use a GPU instance for inference"
  type        = bool
  default     = false
}

variable "gpu_instance_type" {
  description = "EC2 instance type for GPU inference (used when use_gpu_instance is true)"
  type        = string
  default     = "g4dn.xlarge"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for the EC2 instance"
  type        = string
  default     = null
}

variable "app_port" {
  description = "Port on which the inference API will run"
  type        = number
  default     = 8080
}

variable "vllm_port" {
  description = "Port on which the vLLM service will run"
  type        = number
  default     = 8000
}

variable "model_id" {
  description = "HuggingFace model ID to use for inference"
  type        = string
  default     = "solidrust/Hermes-3-Llama-3.1-8B-AWQ"
}

variable "max_model_len" {
  description = "Maximum model context length"
  type        = number
  default     = 14992
}

variable "gpu_memory_utilization" {
  description = "GPU memory utilization for vLLM (0.0-1.0)"
  type        = number
  default     = 0.98
}

variable "tensor_parallel_size" {
  description = "Number of GPUs to use for tensor parallelism (defaults to 1 for single GPU)"
  type        = number
  default     = 1
}

variable "pipeline_parallel_size" {
  description = "Number of pipeline stages for pipeline parallelism (defaults to 1)"
  type        = number
  default     = 1
}

variable "tool_call_parser" {
  description = "The parser to use for function calling in vLLM (options: granite-20b-fc, granite, hermes, internlm, jamba, llama3_json, mistral, pythonic)"
  type        = string
  default     = "hermes"
}

variable "vllm_image_tag" {
  description = "Docker image tag for vLLM"
  type        = string
  default     = "latest"
}

variable "hf_token_parameter_name" {
  description = "Name of the SSM parameter containing the HuggingFace token"
  type        = string
  default     = "/inference/hf_token"
}

variable "enable_https" {
  description = "Whether to enable HTTPS support with ACM certificates"
  type        = bool
  default     = true
}

variable "certificate_domain" {
  description = "Domain for the ACM certificate"
  type        = string
  default     = ""
}

variable "ec2_instance_version" {
  description = "Instance version - increment to force replacement of EC2 instance"
  type        = number
  default     = 1
}

variable "default_proxy_timeout" {
  description = "Default timeout in seconds for proxy connections"
  type        = number
  default     = 75
}

variable "max_proxy_timeout" {
  description = "Maximum timeout in seconds for proxy connections (for large model inference)"
  type        = number
  default     = 300
}
