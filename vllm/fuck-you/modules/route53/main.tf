# Use data source with depends_on to ensure it's properly populated
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "infer" {
  zone_id = var.zone_id != "" ? var.zone_id : data.aws_route53_zone.selected.zone_id
  name    = "infer.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [var.instance_public_ip]
  
  # No longer need to ignore changes since we're using a variable
  # that will be updated with proper value
  lifecycle {
    # To avoid replacement issues with Route53 zone ID
    ignore_changes = [zone_id]
  }
}
