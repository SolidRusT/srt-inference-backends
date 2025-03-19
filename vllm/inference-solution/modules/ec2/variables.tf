variable "scripts_bucket" {
  description = "Name of the S3 bucket containing deployment scripts"
  type        = string
}

variable "main_setup_key" {
  description = "S3 key for the main setup script"
  type        = string
}

variable "name" {
  description = "Name for the EC2 instance and related resources"
  type        = string
  default     = "inference"
}

variable "user_data_timestamp" {
  description = "Timestamp to force user-data update"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for DNS configuration"
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Email address for certificate notifications"
  type        = string
  default     = "admin@example.com"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to deploy the instance into"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "Type of instance to deploy"
  type        = string
  default     = "t3.small"
}

variable "use_gpu" {
  description = "Whether to use a GPU instance for inference"
  type        = bool
  default     = false
}

variable "gpu_instance_type" {
  description = "EC2 instance type for GPU inference"
  type        = string
  default     = "g4dn.xlarge"
}

variable "key_name" {
  description = "Name of the key pair to use for SSH access"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 30
}

variable "app_port" {
  description = "Port on which the API will run"
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
  description = "Whether to enable HTTPS"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository for the app"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "instance_version" {
  description = "Instance version - increment to force replacement"
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