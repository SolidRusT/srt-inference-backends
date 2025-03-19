# AWS EC2 Inference Solution with vLLM

This Terraform solution deploys a fully automated LLM inference solution on AWS EC2 using vLLM for OpenAI-compatible API endpoints. The solution supports GPU acceleration and uses vLLM for high-performance language model inference.

## Recent Updates

- **Controlled Deployment Process**: Added version-based EC2 instance replacement mechanism for zero-downtime deployments
- **Idempotent Infrastructure**: Fixed multiple idempotency issues to ensure consistent Terraform plans
- **HTTPS Support**: Added support for secure HTTPS endpoints using Let's Encrypt certificates
- **Enhanced Monitoring**: Added comprehensive diagnostics and health check scripts
- **Improved Error Handling**: Better token retrieval and service startup logic
- **Force Delete Support**: Added support for clean terraform destroy operations
- **Maintenance Commands**: Added output with useful maintenance commands for easier troubleshooting

## Architecture

The solution includes the following components:

- **VPC**: Secure network environment with public and private subnets
- **EC2 Instance**: Running the latest Ubuntu AMI with Docker pre-installed
- **ECR Repository**: For storing the inference application Docker images
- **Route53 DNS**: Optional DNS record configuration for easy access
- **IAM Roles**: Properly scoped permissions for the EC2 instance
- **Security Groups**: Configured for secure access to the application

## Design Principles

### Idempotency

The infrastructure is designed to be fully idempotent, ensuring that repeated `terraform apply` operations without changed inputs result in no modifications. Key features:

- Fixed timestamps for user_data and other time-sensitive values
- Explicit resource references to avoid lookup changes
- Lifecycle configurations to stabilize resource dependencies

### Controlled Deployment

The solution uses a version-based mechanism for controlled infrastructure updates:

- EC2 instances are versioned via the `ec2_instance_version` variable
- Replacements create new instances before destroying old ones (create_before_destroy)
- Elastic IPs ensure stable endpoints during replacements
- Outputs track version information for monitoring

## Documentation

Detailed documentation is available in the `docs/` directory:

- [Architecture Document](./docs/ARCHITECTURE.md): System design and components
- [Operations Guide](./docs/OPERATIONS.md): Deployment and maintenance instructions
- [Development Roadmap](./docs/DEVELOPMENT_ROADMAP.md): Current status and future plans
- [API Reference](./docs/API_REFERENCE.md): API endpoints documentation
- [Customization Guide](./docs/CUSTOMIZATION.md): How to customize the solution

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform 1.7.0 or later
- Docker (for local testing, optional)
- An existing Route53 hosted zone (if DNS records are needed)
- A HuggingFace token stored in SSM Parameter Store (default path: `/inference/hf_token`)
- (Optional) GPU-enabled EC2 instance for production use

## Deployment

### Step 1: Create the S3 Bucket for Terraform State

Before initializing Terraform, create an S3 bucket to store the Terraform state:

```bash
aws s3api create-bucket \
    --bucket ob-lq-live-inference-solution-terraform-state-us-west-2 \
    --region us-west-2 \
    --create-bucket-configuration LocationConstraint=us-west-2

# Enable S3 bucket versioning for state recovery
aws s3api put-bucket-versioning \
    --bucket ob-lq-live-inference-solution-terraform-state-us-west-2 \
    --versioning-configuration Status=Enabled

# Enable S3 bucket encryption for security
aws s3api put-bucket-encryption \
    --bucket ob-lq-live-inference-solution-terraform-state-us-west-2 \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
```

### Step 2: Quick Start

1. Clone this repository
2. Update `terraform.tfvars` with your desired configuration
3. Make sure the S3 bucket name in `backend.tf` matches the bucket you created
4. Deploy with Terraform:

   ```bash
   terraform init
   terraform apply
   ```

5. Access your API using the outputs provided by Terraform

### Configuration Options

Edit `terraform.tfvars` to customize:

- AWS region
- Environment name (production, staging, etc.)
- Domain name for DNS records
- Admin IPs allowed to access management endpoints
- Instance type and other EC2 parameters

## Customizing the API and Model

The solution comes with a pre-configured vLLM setup. To customize:

1. Update `terraform.tfvars` to change the model and instance parameters:

   ```hcl
   # Example: Switch to GPU and use a different model
   use_gpu_instance = true
   gpu_instance_type = "g4dn.xlarge"
   model_id = "meta-llama/Llama-2-7b-chat-hf"
   max_model_len = 4096
   ```

2. If needed, modify the API proxy in `app/server.js`
3. Run `terraform apply` to rebuild and redeploy

For detailed configuration options, see the [Customization Guide](./docs/CUSTOMIZATION.md).

## Outputs

After deployment, Terraform provides detailed outputs including:

- API endpoint URLs (IP-based and domain-based)
- SSH connection string
- ECR repository URL
- Detailed resource IDs and information

## Maintenance

### Updating the API

#### Method 1: Docker Image Update (No Instance Replacement)

1. Modify the application code in the `app/` directory
2. Run `terraform apply` to rebuild and push the Docker image
3. The EC2 instance will automatically pull the latest image via cron job

#### Method 2: Full Infrastructure Deployment (With Instance Replacement)

1. Edit `terraform.tfvars` and increment the `ec2_instance_version` value:

    ```hcl
    # Change this from the current value (e.g., from 1 to 2)
    ec2_instance_version = 2
    ```

2. Run `terraform apply`

3. Terraform will:
   - Create a new EC2 instance with the updated configuration
   - Wait for the new instance to be ready
   - Move the Elastic IP to the new instance
   - Terminate the old instance

This approach enables zero-downtime deployments while maintaining the same public IP address.

### Cleaning Up

To remove all resources:

```bash
terraform destroy
```

## Security Considerations

- The EC2 instance uses IMDSv2 for enhanced security
- The security group restricts access to configured IP ranges
- All data volumes are encrypted

## Troubleshooting

For detailed troubleshooting steps, refer to the [Operations Guide](./docs/OPERATIONS.md#troubleshooting).

Common issues:

- Check CloudWatch logs for application issues
- SSH to the instance using the provided connection string
- Use the AWS SSM Session Manager for secure console access
- If you encounter Terraform state issues:
  - Verify the S3 bucket exists and is accessible
  - Check the bucket name in `backend.tf` matches the created bucket
  - Ensure you have proper permissions to read/write to the bucket
  - For state lock issues, you may need to manually release locks in S3 using the AWS console

## Project Status

This project is actively maintained. See the [Development Roadmap](./docs/DEVELOPMENT_ROADMAP.md) for information about current status, planned features, and technical debt.

## Version Control

### Git Tags

We use semantic versioning for release management. To tag a new version:

```bash
# List existing tags
git tag -l

# Create a new tag (locally)
git tag -a v1.0.0 -m "Initial stable release"

# Push the tag to the remote repository
git push origin v1.0.0

# Push all tags
git push origin --tags
```

To checkout a specific tag:

```bash
# Create a branch from a tag
git checkout -b branch-name v1.0.0

# Or view the code at a specific tag without creating a branch
git checkout v1.0.0
```

The version number format follows semantic versioning:

- MAJOR version for incompatible API changes (v1.0.0 → v2.0.0)
- MINOR version for backward-compatible functionality additions (v1.0.0 → v1.1.0)
- PATCH version for backward-compatible bug fixes (v1.0.0 → v1.0.1)

### Release Workflow

1. Complete and test your changes
2. Update documentation to reflect changes
3. Create a git tag following semantic versioning
4. Push the tag to the repository
5. Create a detailed release note in your repository management system

## License

See the LICENSE file for details.
