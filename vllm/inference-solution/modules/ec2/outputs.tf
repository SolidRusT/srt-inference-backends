output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.inference.id
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.inference.private_ip
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_eip.inference.public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.inference_instance.id
}

output "instance_role_arn" {
  description = "ARN of the instance IAM role"
  value       = aws_iam_role.inference_instance.arn
}

output "api_endpoint" {
  description = "Full API endpoint URL"
  value       = "http://${aws_eip.inference.public_ip}:${var.app_port}"
}

output "instance_version" {
  description = "The deployed instance version"
  value       = var.instance_version
}
