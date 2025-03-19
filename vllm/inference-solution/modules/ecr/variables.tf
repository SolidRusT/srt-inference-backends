variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "inference-app"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "instance_role_arn" {
  description = "ARN of the IAM role that will be allowed to pull from the ECR repository"
  type        = string
  default     = "" # Make it optional
}
