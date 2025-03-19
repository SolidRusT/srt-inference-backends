# AWS EC2 Inference Solution - Architecture

## Overview

This document describes the architecture and design decisions for the AWS EC2 Inference Solution. The solution provides a fully automated, Infrastructure-as-Code approach to deploying a containerized inference application on AWS with minimal user intervention.

## Core Principles

The solution was designed with the following principles:

- **Idempotency**: Resources can be created, updated, or destroyed reliably
- **Simplicity**: Minimal configuration required to deploy the complete solution
- **Security**: Follow AWS best practices for secure infrastructure
- **Maintainability**: Modular design for easy updates and extensions
- **Automation**: Eliminate manual steps in deployment and operation
- **Resilience**: Multi-layered approach to service management and recovery

## Architecture Components

The solution consists of the following core components:

### 1. Infrastructure Components

#### VPC and Networking

- **VPC**: Isolates the solution in a dedicated virtual network
- **Subnets**:
  - **Public Subnets**: Host the EC2 instance with public internet access
  - **Private Subnets**: Reserved for future expansion (databases, internal services)
- **NAT Gateway**: Enables outbound internet access from private subnets
- **Internet Gateway**: Provides inbound/outbound internet access for public subnets
- **Security Groups**: Restrict network traffic to the EC2 instance

#### Compute

- **EC2 Instance**: Hosts the containerized application
  - Uses latest Ubuntu AMI from Canonical
  - GPU-ready configuration for AI inference
  - Configurable instance types (standard or GPU-accelerated)
  - IAM Role with permissions for ECR and S3 access
  - Security group limits access to specified ports and IP ranges

#### Storage and Registry

- **ECR Repository**: Stores Docker container images
  - Lifecycle policies to limit stored images
  - Repository policies for secure access
- **S3 Bucket**: Stores deployment scripts and configuration
  - Deployment scripts for instance setup
  - Enables more maintainable infrastructure design
  - Securely accessed via IAM role

#### DNS Management

- **Route53 Records**: Maps domain names to EC2 public IP
  - Creates `infer.domain.com` pointing to the EC2 instance

### 2. Application Components

#### Docker Containers

- **API Proxy Container**:
  - NodeJS Express application
  - Proxies requests to the vLLM service
  - Handles security, timeouts, and error management
  - Implements compatible API endpoints (OpenAI format)

- **vLLM Container**:
  - Provides optimized inference for large language models
  - Configurable for different model sizes
  - GPU acceleration with tensor parallelism support
  - Streaming response capability

#### Systemd Services

- **inference-app.service**:
  - Manages the API Proxy container lifecycle
  - Ensures container starts on instance boot
  - Handles automatic restarts on failure

- **vllm.service**:
  - Manages the vLLM inference service
  - GPU integration for accelerated inference
  - Environment variable configuration

#### NGINX Configuration

- Reverse proxy for HTTPS termination
- Intelligent timeout handling for large model inference
- URL pattern-based timeout configuration
- Security headers and optimized settings

#### Multi-layered Service Management

- Boot-time service verification with dependency management
- Intelligent service startup sequencing
- Post-reboot service recovery with container cleanup
- Detailed diagnostics and status checking
- Automated retry and repair mechanisms
- Health endpoint verification
- Service readiness probes

### 3. S3-Based Deployment Architecture

- **Scripts Bucket Module**:
  - Creates and manages the S3 bucket for deployment scripts
  - Renders and uploads templated scripts
  - Organizes scripts by purpose and function

- **Minimal Bootstrap**:
  - Small bootstrap script in user_data (~1KB)
  - Downloads and executes main setup script from S3
  - Ensures EC2 user_data stays well under AWS limits

- **Modular Script Design**:
  - Utility scripts for common functions
  - Service configuration scripts
  - GPU setup for accelerated inference
  - NGINX configuration for optimized web serving

## Infrastructure as Code Structure

```t
inference-solution/
├── app/                         # Application code
│   ├── Dockerfile               # Container definition
│   ├── package.json             # Node.js dependencies
│   └── server.js                # API implementation with timeout handling
├── modules/                     # Terraform modules
│   ├── build/                   # Image build/push logic
│   ├── ec2/                     # EC2 instance configuration
│   │   └── templates/           # Deployment script templates
│   │       ├── bootstrap.sh.tpl # Minimal user_data script
│   │       ├── main-setup.sh.tpl # Main orchestration script
│   │       ├── utility-scripts.sh.tpl # Common utility functions
│   │       ├── services-setup.sh.tpl # Service definitions
│   │       ├── gpu-setup.sh.tpl # GPU driver installation
│   │       └── nginx-setup.sh.tpl # Web server configuration
│   ├── ecr/                     # Container registry
│   ├── route53/                 # DNS configuration
│   ├── scripts_bucket/          # S3 bucket for deployment scripts
│   └── vpc/                     # Network infrastructure
├── backend.tf                   # Terraform state configuration
├── main.tf                      # Main infrastructure definition
├── outputs.tf                   # Output values and information
├── terraform.tf                 # Provider configuration
├── terraform.tfvars             # Variable values
└── variables.tf                 # Variable definitions
```

## Deployment Workflow

1. **Prepare S3 Backend**: Create an S3 bucket for Terraform state
2. **Initialize Terraform**: Run `terraform init`
3. **Apply Infrastructure**: Run `terraform apply`
4. **Build Process**:
   - Application code is built into a Docker image
   - Image is pushed to ECR
5. **Scripts Preparation**:
   - Deployment scripts are templated and uploaded to S3
6. **Instance Provisioning**:
   - EC2 instance is launched with minimal bootstrap script
   - Bootstrap downloads and executes scripts from S3
7. **Service Configuration**:
   - Docker is installed
   - GPU drivers are set up (if enabled)
   - Systemd services are configured
   - NGINX is installed and configured for HTTPS
8. **Application Deployment**:
   - EC2 instance pulls Docker images from ECR and public repositories
   - vLLM and API proxy applications start running
9. **DNS Configuration**: Route53 records are created

## Security Considerations

- **IAM**: Least privilege principle for EC2 instance role
- **Security Groups**: Traffic restrictions by port and source IP
- **S3 Access**: Private bucket with IAM-based access
- **Instance Hardening**:
  - IMDSv2 required
  - Root volume encryption
  - No direct SSH (use Session Manager)
- **HTTPS Support**:
  - Let's Encrypt certificate integration
  - NGINX with secure SSL configuration
  - Security headers (HSTS, CSP, etc.)
- **Container Security**:
  - Minimal base images
  - No unnecessary packages
  - Regular updates via cron job

## Multi-Tier Architecture Benefits

The solution uses a multi-tier architecture with NGINX, Node.js API Proxy, and vLLM. This approach provides several key benefits:

### 1. Separation of Concerns

- **NGINX**: Handles web server concerns (SSL/TLS, security headers, load balancing)
- **Node.js Proxy**: Manages API-specific business logic and request transformation
- **vLLM**: Focuses exclusively on ML inference

This separation follows the single responsibility principle, isolating certificate management, API handling, and ML inference as separate concerns.

### 2. Enhanced Security

- **Defense in Depth**: Multiple layers provide additional security barriers
- **SSL/TLS Management**: Certificate handling by NGINX, a battle-tested web server
- **Request Filtering**: Ability to implement WAF-like capabilities at the proxy layer
- **Authentication**: API key validation and access control at the proxy level

### 3. Operational Flexibility

- **Independent Updates**: Components can be updated separately
- **Certificate Management**: SSL certificates can be renewed without affecting ML components
- **API Customization**: New endpoints can be added without modifying vLLM
- **Error Handling**: Sophisticated error management and client-friendly responses

### 4. Scaling Capabilities

- **Horizontal Scaling**: Proxy can route to multiple vLLM instances
- **Load Distribution**: Sophisticated routing based on model type or request priority
- **Vertical Scaling**: Support for multi-GPU setups with tensor and pipeline parallelism
- **Future Growth**: Architecture supports both single-instance and clustered deployments

### 5. Performance Optimization

- **Request Buffering**: NGINX can buffer requests and responses for improved performance
- **Connection Management**: Better handling of slow clients and network issues
- **Resource Efficiency**: ML component focuses purely on inference, maximizing GPU utilization

## Intelligent Timeout Management

The solution implements a multi-layered timeout management approach:

1. **Application Layer**:
   - Dynamic timeout calculation based on request parameters
   - Model size detection for automatic timeout adjustment
   - Special handling for streaming requests

2. **Proxy Layer**:
   - URL pattern-based timeout configuration in NGINX
   - Extended timeouts for inference endpoints
   - Short timeouts for health checks
   - Default timeouts for other API operations

3. **Configuration Layer**:
   - Configurable timeout values in Terraform variables
   - Default timeout: 90 seconds
   - Extended timeout: 10 minutes (configurable)

This intelligent approach ensures large model inference works reliably while maintaining responsiveness for standard API operations.

## Future Enhancements

1. **Scaling**:
   - Auto Scaling Group for high availability
   - Load Balancer for traffic distribution

2. **Security**:
   - WAF integration for API protection
   - Enhanced authentication mechanisms

3. **Monitoring**:
   - CloudWatch alarms and dashboards
   - Log aggregation and analysis

4. **CI/CD**:
   - GitHub Actions integration
   - Automated testing pipeline

## Technical Improvements in Recent Versions

1. **S3-Based Deployment**: 
   - More maintainable script organization
   - Stays within AWS user_data limits
   - Easier to update individual components

2. **Enhanced Service Management**:
   - Multi-layered service verification
   - Automated recovery mechanisms
   - Better error reporting and diagnostics

3. **Intelligent Timeout Handling**:
   - Request-aware timeout calculation
   - Multiple timeout layers (app, proxy)
   - Configuration through Terraform variables

4. **HTTPS Support**:
   - Let's Encrypt integration
   - Optimized NGINX configuration
   - Security headers and best practices