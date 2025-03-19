# Architectural Decisions - AWS EC2 Inference Solution

## Multi-Tier Architecture: NGINX, Node.js API Proxy, and vLLM

This document explains the architectural decisions behind our multi-tier approach using NGINX, Node.js API Proxy, and vLLM. This design provides significant advantages over a direct vLLM-only approach, particularly for production deployments.

### Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │             │     │             │
│    NGINX    │────▶│  Node.js    │────▶│    vLLM     │
│  (Web Tier) │     │  API Proxy  │     │ (ML Engine) │
│             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
   SSL/TLS,           Business Logic,       ML Inference,
   Timeouts,          Error Handling,       Token Generation,
   Security Headers   Custom Endpoints      Model Serving
```

### Key Benefits

#### 1. Separation of Concerns

**Industry Pattern**: This follows the established microservices/sidecar pattern used extensively in large-scale systems.

| Component | Responsibility | Benefits |
|-----------|---------------|----------|
| NGINX | Web transport, SSL, request routing | Specialized for HTTP(S) handling with decades of optimization |
| Node.js Proxy | API business logic, custom endpoints, error handling | Easily customizable, supports rapid feature development |
| vLLM | ML inference | Optimized for GPU utilization and inference performance |

This separation allows each component to focus on what it does best, rather than forcing the ML engine to also handle web concerns.

#### 2. SSL/TLS Management

**Direct vLLM Approach**: SSL certificates would need to be directly configured within vLLM.

**Our Approach**: NGINX handles all SSL/TLS concerns:
- Industry-standard SSL implementation with extensive security features
- Let's Encrypt integration for automatic certificate renewal
- Certificate updates without affecting ML operations
- Advanced features like OCSP stapling, optimized cipher selection
- Security headers (HSTS, CSP, etc.)

#### 3. Intelligent Timeout Management

Our multi-tier approach enables sophisticated timeout handling essential for LLM inference:

| Component | Timeout Management |
|-----------|-------------------|
| NGINX | Pattern-based routing with different timeouts per endpoint type |
| Node.js Proxy | Dynamic timeouts based on request parameters and model type |
| vLLM | Focused on efficient inference without timeout concerns |

This layered approach prevents timeouts for long-running inference tasks while maintaining responsiveness for simpler operations.

#### 4. API Customization and Extension

With our approach:
- Custom endpoints can be added without modifying vLLM
- API versioning can be implemented at the proxy layer
- Backward compatibility can be maintained across model changes
- Custom error handling provides user-friendly responses

This flexibility would be impossible with direct vLLM exposure.

#### 5. Security Benefits

The multi-tier approach provides defense-in-depth:

| Security Feature | Implementation |
|------------------|---------------|
| API key validation | Node.js proxy layer |
| Request filtering | NGINX rules |
| Rate limiting | Configurable at both NGINX and Node.js layers |
| Input validation | API proxy |
| IP restrictions | NGINX and security groups |

This layered security approach protects the most critical and resource-intensive component (vLLM) from direct exposure.

#### 6. Scaling Capabilities

Our architecture supports sophisticated scaling strategies:

**Vertical Scaling**:
- Multi-GPU setups using tensor and pipeline parallelism
- Optimized for large models (32B+ parameters)

**Horizontal Scaling**:
- Proxy layer can route to multiple vLLM instances
- Load distribution based on model size or request priority
- Future support for Ray-based multi-node clusters

This approach provides flexibility that would be difficult to achieve with direct vLLM exposure.

#### 7. Operational Benefits

The multi-tier architecture significantly improves operational efficiency:

- Component isolation allows independent updates
- SSL certificate renewals don't impact ML components
- API changes can be deployed without restarting inference engine
- Enhanced logging and diagnostics at each layer
- Simplified troubleshooting through component isolation

### Real-World Context

This architecture aligns with industry best practices:

1. **Google's Serving Architecture**: Google's ML serving systems use a similar multi-tier approach with dedicated proxies for their ML engines.

2. **HuggingFace Inference Endpoints**: HuggingFace places their models behind API gateways and load balancers rather than direct exposure.

3. **OpenAI's Architecture**: OpenAI's systems use multiple layers between clients and their model servers.

This pattern is standard for production ML deployments because it balances performance, security, and operational concerns.

### Conclusion

While a direct vLLM-with-SSL approach might seem simpler initially, our multi-tier architecture provides significant advantages for production deployments, particularly around security, scalability, and operational management. This architectural pattern has been validated by industry leaders and aligns with enterprise best practices for ML serving systems.
