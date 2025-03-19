# AWS EC2 Inference Solution - Documentation

## Overview

This directory contains comprehensive documentation for the AWS EC2 Inference Solution. The solution provides a fully automated approach to deploying a containerized inference application on AWS using Terraform.

## Documentation Files

### Core Documentation

- [Architecture Document](./ARCHITECTURE.md): Detailed description of the system architecture, components, and design decisions
- [Operations Guide](./OPERATIONS.md): Instructions for deploying, maintaining, and troubleshooting the solution
- [Development Roadmap](./DEVELOPMENT_ROADMAP.md): Current status, future plans, and technical debt tracking
- [API Reference](./API_REFERENCE.md): Details of the API endpoints provided by the inference application
- [Customization Guide](./CUSTOMIZATION.md): Instructions for customizing the solution for specific requirements

## Key Features

### Idempotent Infrastructure

The solution is designed to be idempotent, ensuring that applying the same configuration multiple times results in the same state. This provides consistency and predictability in deployments.

### Controlled Deployment Process

A version-based deployment mechanism allows for controlled EC2 instance replacements:

1. Update the `ec2_instance_version` in terraform.tfvars
2. Run `terraform apply`
3. New instance is created before old one is destroyed (zero-downtime)
4. Elastic IP is automatically reassigned to the new instance

This approach provides the foundation for a Blue/Green deployment strategy while maintaining simplicity.

## Quick Start

For a quick start, refer to the [Operations Guide](./OPERATIONS.md) which contains step-by-step instructions for deploying the solution.

## Project Structure

```t
inference-solution/
├── app/                         # Application code
│   ├── Dockerfile               # Container definition
│   ├── package.json             # Node.js dependencies
│   └── server.js                # API implementation
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md          # Architecture document
│   ├── API_REFERENCE.md         # API reference
│   ├── CUSTOMIZATION.md         # Customization guide
│   ├── DEVELOPMENT_ROADMAP.md   # Development roadmap
│   ├── OPERATIONS.md            # Operations guide
│   └── README.md                # Documentation index
├── modules/                     # Terraform modules
│   ├── build/                   # Image build/push logic
│   ├── ec2/                     # EC2 instance configuration
│   ├── ecr/                     # Container registry
│   ├── route53/                 # DNS configuration
│   └── vpc/                     # Network infrastructure
├── backend.tf                   # Terraform state configuration
├── main.tf                      # Main infrastructure definition
├── outputs.tf                   # Output values and information
├── README.md                    # Project README
├── terraform.tf                 # Provider configuration
├── terraform.tfvars             # Variable values
└── variables.tf                 # Variable definitions
```

## Getting Help

If you encounter issues or have questions, refer to the following resources:

1. Check the [Operations Guide](./OPERATIONS.md) for troubleshooting tips
2. Review the AWS documentation for the services being used
3. Consult the Terraform documentation for infrastructure-related questions

## Contributing

To contribute to this project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

Please ensure your code follows the project's coding standards and includes appropriate tests.

## License

This project is licensed under the terms specified in the LICENSE file in the root directory.
