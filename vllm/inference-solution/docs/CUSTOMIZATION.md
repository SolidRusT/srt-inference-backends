# AWS EC2 Inference Solution - Customization Guide

This document provides detailed instructions for customizing the inference solution to meet your specific requirements. The solution has been designed with modularity in mind, allowing for easy customization of various components.

## Customizing the Application

### Modifying the API

The sample application is located in the `app/` directory. To customize the application:

1. **Modify server.js**

   - Update the routes and logic according to your needs
   - Add new endpoints for your specific inference requirements
   - Implement authentication/authorization as needed

2. **Add Dependencies**

   - Update `package.json` to include any additional libraries
   - Install dependencies with `npm install`

3. **Test Locally**

   ```bash
   cd app
   npm install
   npm start
   ```

4. **Update the Dockerfile**

   - Change the base image if needed
   - Add any additional build steps
   - Optimize for production use

5. **Rebuild and Deploy**
   - Changes will be automatically built and deployed when running `terraform apply`

### Implementing a Different Backend

To replace the Node.js application with a different backend:

1. **Create a New Application Directory**

   - Create a new directory for your application code
   - Implement your API with your preferred language/framework

2. **Create a New Dockerfile**

   - Define the build process for your application
   - Ensure it exposes the appropriate port
   - Include any necessary environment variables

3. **Update the Build Module**

   - Modify `modules/build/main.tf` to point to your new application directory
   - Update the file hash triggers to match your application files

4. **Update the EC2 Module**
   - Adjust `modules/ec2/templates/inference-app.service.tpl` if needed
   - Update ports and environment variables

## Customizing Infrastructure

### Instance Type and Size

To change the EC2 instance type:

1. Update `terraform.tfvars`:

   ```hcl
   instance_type = "t3.medium"  # Choose the appropriate instance type
   ```

2. Adjust the root volume size in `terraform.tfvars` or `variables.tf`:

   ```hcl
   # In variables.tf
   variable "root_volume_size" {
     description = "Size of the root volume in GB"
     type        = number
     default     = 50  # Increase from the default 30GB
   }
   ```

### Networking Configuration

To customize the VPC and networking:

1. **Change CIDR Ranges**:

   ```hcl
   # In terraform.tfvars
   vpc_cidr = "10.1.0.0/16"  # Set a custom CIDR range
   ```

2. **Modify Subnet Configuration**:
   Edit `main.tf` to change the subnet allocation:

   ```hcl
   private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
   public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 128)]
   ```

3. **Adjust NAT Gateway Configuration**:
   Edit `modules/vpc/main.tf`:

   ```hcl
   enable_nat_gateway = true
   single_nat_gateway = false  # Set to false for one NAT Gateway per AZ
   one_nat_gateway_per_az = true
   ```

### Security Group Rules

To customize security group rules:

1. Edit `modules/ec2/main.tf` to modify the security group:

   ```hcl
   # Add or modify ingress rules
   ingress {
     from_port   = 9090
     to_port     = 9090
     protocol    = "tcp"
     cidr_blocks = var.allowed_cidr_blocks
     description = "Prometheus metrics"
   }
   ```

2. Restrict egress traffic if needed:

   ```hcl
   # Replace the default egress rule
   egress {
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     description = "HTTPS outbound only"
   }
   ```

### Domain and DNS Configuration

To customize DNS settings:

1. Update `terraform.tfvars`:

   ```hcl
   domain_name = "your-custom-domain.com"
   create_route53_records = true
   ```

2. Add additional DNS records by editing `modules/route53/main.tf`:

   ```hcl
   resource "aws_route53_record" "api" {
     zone_id = data.aws_route53_zone.selected.zone_id
     name    = "api.${var.domain_name}"
     type    = "A"
     ttl     = "300"
     records = [var.instance_public_ip]
   }
   ```

## Advanced Customization

### High Availability Setup

To implement a high-availability setup:

1. **Create an Auto Scaling Group Module**

   - Create `modules/asg/main.tf`, `variables.tf`, and `outputs.tf`
   - Implement launch template and auto scaling group resources
   - Configure health checks and scaling policies

2. **Add a Load Balancer Module**

   - Create `modules/alb/main.tf`, `variables.tf`, and `outputs.tf`
   - Configure listeners, target groups, and security groups

3. **Update Main Configuration**
   - Replace the EC2 module with the ASG module in `main.tf`
   - Add the ALB module to `main.tf`
   - Update the Route53 module to point to the load balancer

### HTTPS Support

To add HTTPS support:

1. Make sure `enable_https` is set to `true` in `terraform.tfvars`:

   ```hcl
   enable_https = true
   ```

2. Ensure that `create_route53_records` is set to `true`:

   ```hcl
   create_route53_records = true
   ```

3. Provide a valid email address for Let's Encrypt certificate notifications:

   ```hcl
   email_address = "your-email@example.com"
   ```

4. The deployment will automatically:
   - Create a Let's Encrypt SSL certificate using Certbot
   - Configure the API to use HTTPS
   - Set up automatic certificate renewal
   - Apply security headers for enhanced security

5. To customize the HTTPS configuration, modify the following files:
   - `modules/ec2/templates/user-data.sh.tpl`: Certificate setup
   - `app/server.js`: HTTPS server configuration

### CI/CD Integration

To integrate with CI/CD pipelines:

1. **Separate Build/Deploy Processes**

   - Move the Docker build logic out of Terraform
   - Create CI/CD pipeline configuration files (GitHub Actions, Jenkins, etc.)

2. **Add Terraform Remote Backend Configuration**

   - Update `backend.tf` to use a more collaborative backend like Terraform Cloud

3. **Create Pipeline Stages**
   - Build and test the application
   - Push images to ECR
   - Run Terraform to update infrastructure
   - Run integration tests

## Customizing the vLLM Inference Engine

The solution comes with built-in support for the vLLM OpenAI-compatible API service. Here's how to customize it for your needs:

1. **Changing the Model**

   - Update the `model_id` variable in `terraform.tfvars` to use a different model from HuggingFace
   - Adjust `max_model_len` in `terraform.tfvars` to match the context window of the selected model

2. **GPU Configuration**

   - Set `use_gpu_instance` to `true` in `terraform.tfvars` to use a GPU instance
   - Modify `gpu_instance_type` to select a different instance type (e.g., `g5.xlarge` for newer GPUs)
   - Adjust `gpu_memory_utilization` to control memory allocation (0.0-1.0)

3. **Performance Tuning**

   - Modify the systemd service at `/etc/systemd/system/vllm.service` on the instance to add vLLM-specific parameters
   - Common parameters include `--tensor-parallel-size`, `--block-size`, `--swap-space`, and `--gpu-memory-utilization`

4. **Using Quantized Models**

   - For AWQ models, no special configuration is needed
   - For GPTQ models, add `--quantization gptq` to the vLLM command line
   - For GGUF models, a different approach may be required as vLLM doesn't natively support GGUF

5. **Configuring HuggingFace Token**
   - The solution retrieves the HuggingFace token from SSM Parameter Store
   - Create a secure string parameter in AWS SSM Parameter Store with the name specified in `hf_token_parameter_name` (default is `/inference/hf_token`)
   - Store your HuggingFace token as the parameter value
   - The instance has the necessary IAM permissions to retrieve this parameter
   - For models that don't require a token, you can use a placeholder value

## Example: Customizing for PyTorch Inference

Here's an example of customizing the solution for PyTorch inference:

1. **Create a Custom Dockerfile**

   ```dockerfile
   FROM pytorch/pytorch:1.12.0-cuda11.3-cudnn8-runtime

   WORKDIR /app

   COPY requirements.txt .
   RUN pip install --no-cache-dir -r requirements.txt

   COPY models/ /app/models/
   COPY app/ /app/

   EXPOSE 8080

   CMD ["python", "server.py"]
   ```

2. **Choose an Appropriate Instance Type**

   ```hcl
   # In terraform.tfvars
   instance_type = "g4dn.xlarge"  # GPU-enabled instance
   ```

3. **Update IAM Permissions for S3**

   ```hcl
   # In modules/ec2/main.tf
   resource "aws_iam_policy" "s3_model_access" {
     name        = "${var.name}-s3-model-access"
     description = "Policy for S3 model access"

     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [
         {
           Action = [
             "s3:GetObject",
             "s3:ListBucket"
           ]
           Effect   = "Allow"
           Resource = [
             "arn:aws:s3:::${var.model_bucket}",
             "arn:aws:s3:::${var.model_bucket}/*"
           ]
         }
       ]
     })
   }

   resource "aws_iam_role_policy_attachment" "s3_model_access_attach" {
     role       = aws_iam_role.inference_instance.name
     policy_arn = aws_iam_policy.s3_model_access.arn
   }
   ```

4. **Update the systemd Service Template**

   ```hcl
   # In modules/ec2/templates/inference-app.service.tpl
   ExecStart=/usr/bin/docker run --rm --name inference-app \
       -p ${app_port}:${app_port} \
       -e PORT=${app_port} \
       -e AWS_REGION=${aws_region} \
       -e MODEL_BUCKET=${model_bucket} \
       --gpus all \
       ${ecr_repository_url}:latest
   ```
