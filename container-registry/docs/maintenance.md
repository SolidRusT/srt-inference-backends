# Container Registry Maintenance Guide

This document provides instructions for maintaining the Container Registry and vLLM service.

## Regular Maintenance Tasks

### Registry Garbage Collection

The registry automatically runs garbage collection weekly (by default at 2am on Sunday), but you can manually trigger it with:

```bash
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

### Checking Registry Status

Check the status of your registry:

```bash
/usr/local/bin/registry-status.sh
```

### Checking vLLM Status

Check the status of your vLLM service:

```bash
/usr/local/bin/vllm-status.sh
```

## Backup Procedures

### Backing Up Registry Data

1. First, stop the registry container:
   ```bash
   docker stop registry
   ```

2. Backup the registry data directory:
   ```bash
   tar -czf registry-backup-$(date +%Y%m%d).tar.gz /var/lib/registry
   ```

3. Restart the registry:
   ```bash
   docker start registry
   ```

### Backing Up Configuration

Backup all configuration files:

```bash
tar -czf registry-config-$(date +%Y%m%d).tar.gz /etc/registry
```

## Updating Components

### Updating the Registry Container

1. Update the registry image:
   ```bash
   docker pull registry:2
   ```

2. Restart the registry service:
   ```bash
   docker stop registry
   docker rm registry
   ansible-playbook -i inventory/hosts.yml site.yml --tags registry
   ```

### Updating vLLM Server

To update the vLLM server with a new image or configuration:

```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags vllm
```

## Troubleshooting

### Common Registry Issues

| Issue | Resolution |
|-------|------------|
| Registry not responding | Run `/usr/local/bin/registry-health-check.sh` |
| "No space left on device" | Increase storage or run garbage collection |
| Authentication failure | Check htpasswd file in `/etc/registry/auth` |
| TLS certificate issues | Regenerate certificates or check expiration date |

### Common vLLM Issues

| Issue | Resolution |
|-------|------------|
| vLLM service not responding | Run `/usr/local/bin/vllm-health-check.sh` |
| GPU memory errors | Check GPU memory usage with `nvidia-smi` |
| Model loading failures | Check model permissions and HF token configuration |
| Performance degradation | Check for CPU throttling or GPU thermal issues |

## Monitoring

Both the registry and vLLM services expose Prometheus metrics on port 9100. You can configure a Prometheus server to scrape these endpoints for comprehensive monitoring.

### Key Metrics to Monitor

- **Registry Metrics**:
  - Number of requests per second
  - Storage usage
  - Response time

- **vLLM Metrics**:
  - GPU memory usage
  - Request latency
  - Token generation speed
  - Queue length
