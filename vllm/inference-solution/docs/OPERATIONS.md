# AWS EC2 Inference Solution - Operational Guide

## Overview

This operational guide provides detailed instructions for deploying, maintaining, and troubleshooting the AWS EC2 Inference Solution. The solution is designed to be fully automated through Terraform, requiring minimal manual intervention during normal operation.

## Prerequisites

Before deploying the solution, ensure you have:

- AWS CLI installed and configured with appropriate credentials
- Terraform 1.7.0 or newer installed
- Docker installed (for local testing or development)
- Git installed (for version control)
- An existing Route53 hosted zone (if DNS functionality is required)

## Initial Deployment

### Step 1: Create S3 Bucket for Terraform State

```bash
# Create the S3 bucket in the specified region
aws s3api create-bucket \
    --bucket ob-lq-live-inference-solution-terraform-state-us-west-2 \
    --region us-west-2 \
    --create-bucket-configuration LocationConstraint=us-west-2

# Enable versioning for state file recovery
aws s3api put-bucket-versioning \
    --bucket ob-lq-live-inference-solution-terraform-state-us-west-2 \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
    --bucket ob-lq-live-inference-solution-terraform-state-us-west-2 \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
```

### Step 2: Store HuggingFace Token in SSM Parameter Store

The vLLM service requires a HuggingFace token to access models.

Validate your token locally:

```bash
export HF_TOKEN=<your_actual_token>
curl https://huggingface.co/api/whoami-v2 -H "Authorization: Bearer ${HF_TOKEN}"
```

Store your token securely in SSM Parameter Store:

```bash
export HF_TOKEN=<your_actual_token>
aws ssm put-parameter \
    --name "/inference/hf_token" \
    --value "${HF_TOKEN}" \
    --type SecureString \
    --region us-west-2
```

If you need to update the token later:

```bash
export HF_TOKEN=<your_new_token>
aws ssm put-parameter \
    --name "/inference/hf_token" \
    --value "${HF_TOKEN}" \
    --type SecureString \
    --region us-west-2 \
    --overwrite
```

### Step 3: Clone the Repository

```bash
git clone <repository-url>
cd inference-solution
```

### Step 4: Configure Variables

Edit `terraform.tfvars` to customize the deployment:

```hcl
# AWS Configuration
region = "us-west-2"

# Environment name
environment = "production"

# Domain Configuration
domain_name = "your-domain.com"
create_route53_records = true

# Admin settings
allowed_cidr_blocks = ["your-ip/32"]
email_address = "admin@your-domain.com"

# EC2 instance settings
instance_type = "t3.small"
root_volume_size = 100  # Size in GB
use_gpu_instance = true  # Set to true to use GPU instance
gpu_instance_type = "g5.2xlarge"  # GPU instance type
key_name = "your-ssh-key"  # Set to null if not needed
app_port = 8080

# Timeout Configuration
default_proxy_timeout = 90    # Default timeout in seconds for most API operations
max_proxy_timeout = 600      # Extended timeout for large model inference (10 minutes)

# vLLM Configuration
model_id = "solidrust/Hermes-3-Llama-3.1-8B-AWQ"  # The model to use
max_model_len = 14992  # Maximum model context length
gpu_memory_utilization = 0.95  # GPU memory utilization (0.0-1.0)
```

### Step 5: Deploy the Solution

```bash
# Initialize Terraform
terraform init

# Validate the configuration
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply
```

### Step 6: Verify Deployment

After deployment completes, Terraform will display various outputs, including:

- API endpoint URL
- SSH connection string
- ECR repository URL
- DNS records (if enabled)

Verify that the application is running by accessing the API endpoint URL.

## Routine Operations

### Deployment and Updates

There are several types of updates you can perform:

#### 1. Docker Image Updates (No Instance Replacement)

For changes to the application code only:

1. Make changes to the application code in the `app/` directory
2. Run `terraform apply` to trigger a rebuild and push of the Docker image
3. The EC2 instance will automatically pull the new image via cron job

#### 2. Script Updates (No Instance Replacement)

For changes to deployment scripts only:

1. Make changes to the script templates in `modules/ec2/templates/`
2. Run `terraform apply` to update the S3 bucket with new script versions
3. Connect to the instance and manually run the updated scripts if needed:
   ```bash
   aws s3 cp s3://<scripts-bucket>/<script-path> /tmp/updated-script.sh
   chmod +x /tmp/updated-script.sh
   sudo /tmp/updated-script.sh
   ```

#### 3. Full Infrastructure Updates (With Instance Replacement)

For more significant changes that require a fresh EC2 instance:

1. Edit `terraform.tfvars` and increment the `ec2_instance_version` value:

  ```hcl
  # Change this from the current value (e.g., from 4 to 5)
  ec2_instance_version = 5
  ```

2. Run `terraform apply`

3. Terraform will:
   - Create a new EC2 instance with the updated configuration
   - Wait for the new instance to be ready (thanks to create_before_destroy)
   - Move the Elastic IP to the new instance
   - Terminate the old instance

This controlled replacement provides zero-downtime deployments while maintaining the same public IP address.

### Connecting to the EC2 Instance

Use AWS Systems Manager Session Manager for secure shell access:

```bash
aws ssm start-session --target <instance-id>
```

Where `<instance-id>` is the value from `terraform output instance_id`.

Alternatively, if you configured an SSH key:

```bash
ssh ubuntu@<instance-public-ip>
```

Where `<instance-public-ip>` is the value from `terraform output instance_public_ip`.

### Viewing Application Logs

To view application logs on the EC2 instance:

```bash
# View Docker container logs
docker logs inference-app
docker logs vllm-service

# View systemd service logs
journalctl -u inference-app.service
journalctl -u vllm.service

# View user-data bootstrap logs
cat /var/log/user-data.log

# Check service status with the built-in tool
/usr/local/bin/check-services.sh
```

### Manually Updating the Container

If you need to manually trigger a container update:

```bash
sudo /usr/local/bin/update-inference-app.sh
```

## Timeout Management

The solution implements intelligent timeout management to handle large model inference. You can configure these timeouts in your `terraform.tfvars` file:

```hcl
# Timeout Configuration
default_proxy_timeout = 90    # Default timeout in seconds for most API operations
max_proxy_timeout = 600      # Extended timeout for large model inference (10 minutes)
```

### Testing Different Timeout Scenarios

1. **Standard API Call (Default Timeout)**
   ```bash
   curl -X POST \
     http://<instance-public-ip>:8080/v1/chat/completions \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "solidrust/Hermes-3-Llama-3.1-8B-AWQ",
       "messages": [
         {"role": "user", "content": "Explain what AWS EC2 is in one paragraph."}
       ],
       "max_tokens": 100
     }'
   ```

2. **Large Model Inference (Extended Timeout)**
   ```bash
   curl -X POST \
     http://<instance-public-ip>:8080/v1/chat/completions \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "Qwen/QwQ-32B",
       "messages": [
         {"role": "user", "content": "Write a detailed 10-paragraph essay about cloud computing."}
       ],
       "max_tokens": 4000
     }'
   ```

3. **Streaming Request**
   ```bash
   curl -X POST \
     http://<instance-public-ip>:8080/v1/chat/completions \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "solidrust/Hermes-3-Llama-3.1-8B-AWQ",
       "messages": [
         {"role": "user", "content": "Explain quantum computing to me."}
       ],
       "stream": true
     }'
   ```

### Checking Timeout Configuration

To verify the current timeout settings:

```bash
# Check NGINX timeout configuration
cat /etc/nginx/sites-available/inference-api | grep timeout

# Check Node.js timeout settings
docker inspect inference-app | grep TIMEOUT
```

## Scaling and Modifications

### Changing Instance Type

To change the EC2 instance type:

1. Update the `instance_type` or `gpu_instance_type` variable in `terraform.tfvars`
2. Increment the `ec2_instance_version` value
3. Run `terraform apply`

This will replace the EC2 instance while maintaining all configuration.

### Changing Models

To switch to a different language model:

1. Update the `model_id` in terraform.tfvars
2. Adjust `max_model_len` and `gpu_memory_utilization` as needed
3. Increment the `ec2_instance_version` value
4. Run `terraform apply`

### Adding Custom Domain Names

To add additional domain names:

1. Modify the Route53 module in `modules/route53/main.tf`
2. Add new record resources for each domain
3. Run `terraform apply`

## Monitoring and Health Checks

### Health Check Endpoint

The application provides a health check endpoint at `/health`. Use this to verify the API is functioning correctly:

```bash
curl http://<instance-public-ip>:8080/health
```

A successful response will be:

```json
{ 
  "status": "ok", 
  "message": "API and vLLM service are healthy",
  "version": "1.1.1"
}
```

### CloudWatch Metrics

The solution collects standard EC2 metrics in CloudWatch. Key metrics to monitor:

- CPU Utilization
- Memory Utilization
- Disk Space
- Network Traffic
- GPU Utilization (if using GPU)

### Advanced Diagnostics

The solution includes built-in diagnostic tools to help troubleshoot issues:

```bash
# Comprehensive service status check
sudo /usr/local/bin/check-services.sh

# Run the vLLM diagnostic script
sudo /usr/local/bin/test-vllm.sh

# Wait for vLLM to be available (with timeout)
sudo /usr/local/bin/wait-for-vllm.sh

# Check the installation log
cat /var/log/user-data.log

# Check logs from the post-reboot setup
cat /var/log/post-reboot-setup.log
cat /var/log/post-reboot-vllm-test.log

# Test HuggingFace token retrieval
sudo /usr/local/bin/get-hf-token.sh

# Check NVIDIA drivers (GPU instances)
nvidia-smi
```

The enhanced `check-services.sh` script provides comprehensive diagnostics including:

- System information (uptime, memory, disk usage)
- Service status (active/enabled state of all services)
- Docker container status
- NVIDIA GPU status
- Network port status (which services are listening)
- API health checks for both vLLM and inference-app
- Container logs for both services
- Systemd service logs
- Startup script verification
- Recent boot logs

When running `terraform apply`, the output includes useful maintenance commands that can be run from your local machine for remote diagnostics.

## S3-Based Deployment

The solution uses an S3 bucket to store deployment scripts, which are downloaded and executed by the EC2 instance during provisioning. This architecture allows for:

- Keeping user_data scripts small (under AWS 16KB limit)
- More maintainable script organization
- Ability to update scripts without rebuilding instances

### How It Works

1. Terraform creates an S3 bucket during `terraform apply`
2. Templates are rendered and uploaded to this bucket
3. The EC2 instance bootstrap script downloads scripts from S3
4. Scripts are executed in the correct order

### Key Script Locations on the Instance

```
/opt/inference/               # Base directory for inference setup
├── config.env                # Environment variables
├── main-setup.sh             # Main orchestration script
└── scripts/                  # Component scripts
    ├── utility-scripts.sh    # Utility functions
    ├── services-setup.sh     # Service definitions
    ├── gpu-setup.sh          # GPU driver installation (if enabled)
    └── nginx-setup.sh        # Web server configuration (if HTTPS enabled)
```

### Manually Running Scripts

If you need to manually run or update a specific script:

```bash
# Download a script from S3
aws s3 cp s3://<scripts-bucket>/scripts/nginx-setup.sh /tmp/nginx-setup.sh
chmod +x /tmp/nginx-setup.sh

# Execute the script
sudo /tmp/nginx-setup.sh
```

## Troubleshooting

## Service Startup Mechanism

The solution implements a sophisticated service startup sequence to ensure reliable operation:

### 1. Boot-Time Sequence

1. Bootstrap script runs via user-data
2. Component scripts are downloaded from S3 and executed
3. Services are enabled but not immediately started
4. vLLM service is started first with retry mechanism
5. System waits for vLLM to be fully available using health checks
6. Inference-app service starts only after vLLM is verified working

### 2. Post-Reboot Sequence

After a reboot (especially important for GPU instances that require driver initialization):

1. Post-reboot script runs automatically from `/var/lib/cloud/scripts/per-boot/`
2. Any running containers are stopped and removed for clean startup
3. Services are restarted in the correct sequence
4. Health checks verify full system operation
5. Detailed logs are written to `/var/log/post-reboot-setup.log`

### 3. Service Health Monitoring

The solution provides several tools for health verification:

- `/usr/local/bin/wait-for-vllm.sh`: Waits for vLLM to be responding on health endpoint
- `/usr/local/bin/test-vllm.sh`: Tests vLLM functionality and configuration
- `/usr/local/bin/check-services.sh`: Comprehensive system health check
- `/usr/local/bin/health-check.sh`: Quick check for monitoring integration

### Common Issues and Resolutions

#### Docker Image Build Fails

**Symptoms**: `terraform apply` fails during the build step.

**Resolution**:

1. Check the build script output
2. Verify AWS credentials have ECR permissions
3. Run the build script manually to see detailed errors:

```bash
cd modules/build/scripts
bash build_and_push.sh <ecr-repo-url> <aws-region> <app-path>
```

#### Services Not Starting

**Symptoms**: EC2 instance is running but services are inactive.

**Resolution**:

1. Connect to the instance using Session Manager
2. Run the status check script: `sudo /usr/local/bin/check-services.sh`
3. Check service status: 
   ```bash
   sudo systemctl status inference-app
   sudo systemctl status vllm
   ```
4. View service logs: 
   ```bash
   journalctl -u inference-app -n 100
   journalctl -u vllm -n 100
   ```
5. Try manually starting the services:
   ```bash
   sudo systemctl start vllm
   sudo systemctl start inference-app
   ```
6. Verify the bootstrap logs: `cat /var/log/user-data.log`

#### vLLM Service Fails with Large Models

**Symptoms**: vLLM service fails to start with large models (e.g., 32B parameter models).

**Resolution**:

1. Check GPU memory: `nvidia-smi`
2. Reduce `gpu_memory_utilization` in terraform.tfvars (e.g., from 0.98 to 0.90)
3. Use a larger GPU instance type with more memory
4. Try adjusting tensor parallelism:
   ```hcl
   tensor_parallel_size = 4  # Use multiple GPUs for one model
   ```
5. For multi-GPU setups, verify all GPUs are working: `nvidia-smi`

#### Timeout Errors with Large Models

**Symptoms**: API returns 504 Gateway Timeout for large model requests.

**Resolution**:

1. Increase the timeout values in terraform.tfvars:
   ```hcl
   default_proxy_timeout = 90
   max_proxy_timeout = 900  # Increase to 15 minutes
   ```
2. Deploy the changes with `terraform apply`
3. For immediate testing, you can modify NGINX configuration manually:
   ```bash
   sudo sed -i 's/proxy_read_timeout 600s;/proxy_read_timeout 900s;/' /etc/nginx/sites-available/inference-api
   sudo systemctl reload nginx
   ```

#### S3 Script Download Failures

**Symptoms**: EC2 instance fails to download scripts from S3 during startup.

**Resolution**:

1. Check the bootstrap log: `cat /var/log/user-data.log`
2. Verify IAM role permissions for S3 access
3. Check S3 bucket exists and contains the expected scripts:
   ```bash
   aws s3 ls s3://<scripts-bucket>/scripts/
   ```
4. If needed, manually download and run the scripts:
   ```bash
   aws s3 cp s3://<scripts-bucket>/scripts/main-setup.sh /opt/inference/
   chmod +x /opt/inference/main-setup.sh
   sudo /opt/inference/main-setup.sh
   ```

## Security Considerations

### Rotating IAM Credentials

Regularly rotate AWS access keys:

1. Create new access keys in IAM
2. Update AWS CLI configuration
3. Verify functionality
4. Delete old access keys

### Updating Docker Images

Keep base images up to date:

1. Update the `FROM` line in the Dockerfile
2. Run `terraform apply` to rebuild and redeploy

### Patching the EC2 Instance

The EC2 instance uses Ubuntu, which can be updated with:

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

## Complete Removal

This solution has been designed to be fully destroyable with a single command. To completely remove all resources:

```bash
terraform destroy
```

This will:

1. Terminate the EC2 instance
2. Delete the ECR repository and images (using force_delete)
3. Delete the S3 scripts bucket and contents
4. Remove DNS records
5. Remove IAM roles and policies (with force_detach_policies)
6. Delete the security groups, VPC, and associated resources

All resources are configured to properly handle dependencies and allow clean deletion, even when containing data or having external associations.

> Note: The S3 bucket for Terraform state must be manually deleted if no longer needed, as it exists outside of this Terraform configuration.

## Infrastructure Design Principles

### S3-based Deployment Architecture

The solution uses an S3-based deployment approach with these benefits:

1. **Modularity**: Scripts are organized by function (utility, service, GPU, NGINX)
2. **Maintainability**: Each script can be updated independently
3. **Size Constraints**: Avoids AWS EC2 user_data 16KB limit
4. **Version Control**: Scripts can be versioned and rolled back easily
5. **Reusability**: Common scripts can be shared across environments

### Multi-Layer Service Management

The solution implements a robust service management approach:

1. **Initial Service Start**: During bootstrap using systemd
2. **Health Check Integration**: Periodic service verification
3. **Post-Reboot Recovery**: Automatic service restart after system reboots
4. **Manual Diagnostics**: Built-in tools for service status checking

### Intelligent Timeout Handling

The solution provides sophisticated timeout management:

1. **Application-Layer Timeouts**: Dynamic timeout calculation in Node.js
2. **NGINX Timeouts**: Pattern-based timeout configuration in NGINX
3. **Configurable Values**: Easy adjustment through Terraform variables
4. **Request-Aware**: Adjusts timeouts based on model size and request type

These design principles ensure a reliable, maintainable, and resilient inference solution that can handle diverse models and workloads.