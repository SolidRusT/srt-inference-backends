variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "inference"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
}

variable "region" {
  description = "AWS region for the bucket"
  type        = string
}

variable "aws_region" {
  description = "AWS region for script variables"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "app_port" {
  description = "Port on which the API will run"
  type        = number
}

variable "vllm_port" {
  description = "Port on which the vLLM service will run"
  type        = number
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "hf_token_parameter_name" {
  description = "Name of the SSM parameter containing the HuggingFace token"
  type        = string
}

variable "use_gpu" {
  description = "Whether to use a GPU for inference"
  type        = bool
}

variable "model_id" {
  description = "HuggingFace model ID to use for inference"
  type        = string
}

variable "max_model_len" {
  description = "Maximum model context length"
  type        = number
}

variable "gpu_memory_utilization" {
  description = "GPU memory utilization for vLLM"
  type        = number
}

variable "vllm_image_tag" {
  description = "Docker image tag for vLLM"
  type        = string
}

variable "enable_https" {
  description = "Whether to enable HTTPS"
  type        = bool
}

variable "domain_name" {
  description = "Domain name for certificates and DNS"
  type        = string
}

variable "admin_email" {
  description = "Admin email for certificate notifications"
  type        = string
}

variable "default_proxy_timeout" {
  description = "Default timeout for proxy connections in seconds"
  type        = number
}

variable "max_proxy_timeout" {
  description = "Maximum timeout for proxy connections in seconds"
  type        = number
}

variable "tensor_parallel_size" {
  description = "Number of GPUs to use for tensor parallelism"
  type        = number
}

variable "pipeline_parallel_size" {
  description = "Number of pipeline stages for pipeline parallelism"
  type        = number
}

variable "tool_call_parser" {
  description = "The parser to use for function calling in vLLM"
  type        = string
}

variable "instance_version" {
  description = "Instance version - used for tracking"
  type        = number
}