output "certificate_arn" {
  description = "The ARN of the certificate"
  value       = aws_acm_certificate.cert.arn
}

output "domain_validation_options" {
  description = "Domain validation options for the certificate"
  value       = aws_acm_certificate.cert.domain_validation_options
}

output "validation_record_fqdns" {
  description = "FQDNs of the DNS validation records"
  value       = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = aws_acm_certificate.cert.status
}
