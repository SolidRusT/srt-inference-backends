# Container Registry Architecture

This document describes the architecture of the Container Registry solution with vLLM integration.

## Overview

The solution consists of two main components:

1. **Docker Registry**: A private container registry for storing and distributing Docker images
2. **vLLM Service**: A high-performance inference server for Large Language Models

These components are deployed on separate servers for optimal performance and scalability.

## System Architecture

```
+------------------------+        +------------------------+
|                        |        |                        |
|   Registry Servers     |        |     vLLM Servers       |
|   ================     |        |   ================     |
|                        |        |                        |
|   +--------------+     |        |   +--------------+     |
|   | Docker       |     |        |   | vLLM Server  |     |
|   | Registry     |     |        |   | Container    |     |
|   +--------------+     |        |   +--------------+     |
|                        |        |                        |
|   +--------------+     |        |   +--------------+     |
|   | Health Check |     |        |   | Health Check |     |
|   | Scripts      |     |        |   | Scripts      |     |
|   +--------------+     |        |   +--------------+     |
|                        |        |                        |
+------------------------+        +------------------------+
```

## Component Details

### Docker Registry

- **Container**: Official Docker Registry v2
- **Authentication**: HTTP Basic Auth with bcrypt hashing
- **TLS**: Self-signed certificates (can be replaced with proper certificates)
- **Storage**: Filesystem-based with configurable path
- **Health Monitoring**: Automated health checks and self-healing

### vLLM Service

- **Framework**: vLLM (https://github.com/vllm-project/vllm)
- **API**: FastAPI-based HTTP API
- **Models**: Hugging Face models (configurable)
- **Tensor Parallelism**: Support for multi-GPU inference
- **Quantization**: Optional AWQ or SqueezeLL quantization support
- **Monitoring**: Prometheus metrics for GPU usage, request throughput, etc.

## Data Flow

1. **Image Publishing Workflow**:
   ```
   Developer -> docker push -> Registry Server -> Storage
   ```

2. **Image Consumption Workflow**:
   ```
   Consumer -> docker pull -> Registry Server -> Consumer's Docker daemon
   ```

3. **vLLM Inference Workflow**:
   ```
   Client -> HTTP Request -> vLLM Server -> Model Inference -> Response
   ```

## Security Considerations

- **Registry Authentication**: HTTP Basic Auth with encrypted passwords
- **TLS Communication**: All communications encrypted with TLS
- **Network Segmentation**: Registry and vLLM servers on separate networks
- **Access Control**: IP-based access restrictions configurable
- **Monitoring**: Continuous health checks and metrics collection

## Deployment Architecture

The solution uses Ansible for automated deployment with:

- **Inventory**: Defines servers and their roles
- **Roles**: Modular configuration for common, docker, registry, and vLLM components
- **Templates**: Jinja2 templates for dynamic configuration

## Network Requirements

- **Registry Server**:
  - Port 5000: Registry API (TCP)
  - Port 9100: Prometheus metrics (TCP)

- **vLLM Server**:
  - Port 8000: HTTP API (TCP)
  - Port 8080: Admin API (TCP)
  - Port 9100: Prometheus metrics (TCP)

## Persistent Storage

- **Registry**: `/var/lib/registry` for image storage
- **vLLM**: `/app/models` for model storage

## Performance Optimizations

1. **Registry**:
   - In-memory cache for frequently accessed blobs
   - Tuned filesystem parameters for optimal I/O
   - Regular garbage collection for storage efficiency

2. **vLLM**:
   - GPU memory optimization
   - Tensor parallelism for large models
   - Quantization options for memory efficiency
   - Optimized KV cache management
