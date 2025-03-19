terraform {
  backend "s3" {
    bucket         = "ob-lq-live-inference-solution-terraform-state-us-west-2"
    key            = "platform/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    # Migrating from DynamoDB to native S3 locking (as of Jan 2025)
    use_lockfile   = true  # New S3 native locking
  }
}