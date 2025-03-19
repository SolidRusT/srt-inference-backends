output "zone_name" {
  description = "The name of the Route53 zone"
  value       = data.aws_route53_zone.selected.name
}

output "zone_id" {
  description = "The ID of the Route53 zone"
  value       = data.aws_route53_zone.selected.zone_id
}

output "dns_records" {
  description = "List of DNS records created"
  value = {
    infer = "infer.${var.domain_name}"
  }
}

output "full_domain" {
  description = "Full domain name for the inference API"
  value       = "infer.${var.domain_name}"
}
