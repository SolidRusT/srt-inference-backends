# Container Registry Solution

A complete solution for deploying a scalable and maintainable container registry with vLLM integration using Ansible and Debian.

## Architecture

This solution includes:

1. **Container Registry** - A self-hosted Docker registry for storing and distributing container images
2. **vLLM Service** - A high-performance LLM serving solution for AI models

## Features

- **Fully Automated Deployment**: Zero manual steps required
- **Scalable Architecture**: Designed to scale horizontally
- **Health Monitoring**: Automated health checks and self-healing
- **Secured Access**: TLS encryption and authentication
- **Performance Optimized**: Tuned for high-throughput applications

## Requirements

- Debian-based servers (tested on Debian 11+)
- Python 3.8+
- Ansible 2.9+
- For vLLM: NVIDIA GPUs with CUDA support

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/container-registry.git
   cd container-registry
   ```

2. Update the inventory file in `ansible/inventory/hosts.yml` with your server details.

3. Run the Ansible playbook:
   ```bash
   cd ansible
   ansible-playbook site.yml
   ```

## Configuration

The solution is highly configurable through variables defined in:

- `ansible/roles/registry/defaults/main.yml` - Registry configuration
- `ansible/roles/vllm/defaults/main.yml` - vLLM configuration

## Directory Structure

```
container-registry/
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml
│   ├── roles/
│   │   ├── common/
│   │   ├── docker/
│   │   ├── registry/
│   │   └── vllm/
│   ├── ansible.cfg
│   └── site.yml
└── docs/
    ├── maintenance.md
    └── scaling.md
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.