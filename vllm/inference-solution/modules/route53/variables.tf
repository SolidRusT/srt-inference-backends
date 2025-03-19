variable "domain_name" {
  description = "Domain name to create DNS records for"
  type        = string
}

variable "create_example_record" {
  description = "Whether to create a record for Example"
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Route53 zone ID (if known to avoid lookups)"
  type        = string
  default     = ""
}

variable "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  type        = string
}

