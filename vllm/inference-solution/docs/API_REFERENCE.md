# AWS EC2 Inference Solution - API Reference

## Overview

This document provides details about the REST API endpoints exposed by the inference application. The API is built using Node.js and Express, acting as a proxy to the vLLM OpenAI-compatible inference service running on the same machine. The API proxy provides secure access, SSL termination, and consistent error handling.

## Base URLs

- **Development**: `http://localhost:8080`
- **Production**:
  - IP-based: `http://<ec2-instance-ip>:8080`
  - Domain-based: `https://infer.<your-domain>` (when DNS records and HTTPS are enabled)

## Authentication

The API currently does not implement authentication. Future versions will include:

- API key authentication
- JWT token-based authentication
- AWS IAM-based authentication

## Endpoints

### Health Check

Verify the API service is running properly.

```http
GET /health
```

#### Response

```json
{
  "status": "ok",
  "message": "API and vLLM service are healthy",
  "version": "1.1.0"
}
```

#### Status Codes

- `200 OK`: Service is healthy
- `503 Service Unavailable`: vLLM service is not available

### Root Endpoint

Get basic information about the API service.

```http
GET /
```

#### Response

```json
{
  "message": "vLLM Inference API",
  "timestamp": "2025-03-12T12:34:56.789Z",
  "version": "1.1.0",
  "modelInfo": "solidrust/Hermes-3-Llama-3.1-8B-AWQ"
}
```

#### Status Codes

- `200 OK`: Request successful

### List Available Models

Get information about the available models.

```http
GET /v1/models
```

#### Response

```json
{
  "object": "list",
  "data": [
    {
      "id": "solidrust/Hermes-3-Llama-3.1-8B-AWQ",
      "object": "model",
      "created": 1710323150,
      "owned_by": "vLLM"
    }
  ]
}
```

#### Status Codes

- `200 OK`: Request successful
- `503 Service Unavailable`: vLLM service unavailable

### OpenAI-Compatible Chat Completion Endpoint

Submit chat requests in OpenAI format for inference processing.

```http
POST /v1/chat/completions
```

#### Request Body

```json
{
  "model": "<model-name>",
  "messages": [
    { "role": "system", "content": "You are a helpful assistant." },
    { "role": "user", "content": "Tell me about AWS EC2." }
  ],
  "max_tokens": 512,
  "temperature": 0.7,
  "stream": false
}
```

#### Response

```json
{
  "id": "cmpl-7a2e8938ebc44755bdcc45d37df1b106",
  "object": "chat.completion",
  "created": 1710323152,
  "model": "<model-name>",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "AWS EC2 (Elastic Compute Cloud) is a web service provided by Amazon Web Services that offers resizable compute capacity in the cloud..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 27,
    "completion_tokens": 142,
    "total_tokens": 169
  }
}
```

#### Status Codes

- `200 OK`: Inference successful
- `400 Bad Request`: Invalid input data
- `500 Internal Server Error`: Processing error
- `503 Service Unavailable`: vLLM service unavailable

### Text Completion Endpoint

Submit text prompts for completion in OpenAI format.

```http
POST /v1/completions
```

#### Request Body

```json
{
  "model": "<model-name>",
  "prompt": "Write a short paragraph about AWS EC2",
  "max_tokens": 256,
  "temperature": 0.7
}
```

#### Response

```json
{
  "id": "cmpl-abc123def456",
  "object": "text.completion",
  "created": 1710325001,
  "model": "<model-name>",
  "choices": [
    {
      "text": "AWS EC2 (Elastic Compute Cloud) is Amazon's flagship cloud computing service that allows users to rent virtual computers...",
      "index": 0,
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 8,
    "completion_tokens": 54,
    "total_tokens": 62
  }
}
```

### Tokenize Endpoint

Convert text to tokens according to the model's tokenizer.

```http
POST /tokenize
```

#### Request Body (for chat format)

```json
{
  "model": "<model-name>",
  "messages": [
    { "role": "user", "content": "Hello, how are you?" }
  ]
}
```

#### Request Body (for completion format)

```json
{
  "model": "<model-name>",
  "prompt": "Hello, how are you?"
}
```

#### Response

```json
{
  "tokens": [1, 23, 5, 7890, 12, 35, 23, 789]
}
```

### Detokenize Endpoint

Convert token IDs back to text.

```http
POST /detokenize
```

#### Request Body

```json
{
  "model": "<model-name>",
  "tokens": [1, 23, 5, 7890, 12, 35, 23, 789]
}
```

#### Response

```json
{
  "text": "Hello, how are you?"
}
```

### Version Endpoint

Get the version information of the vLLM server and proxy.

```http
GET /version
```

#### Response

```json
{
  "version": "0.2.5",
  "proxy_version": "1.1.0"
}
```

### Embeddings Endpoint

Generate embeddings for input text.

```http
POST /v1/embeddings
```

#### Request Body

```json
{
  "model": "<embedding-model-name>",
  "input": "Text to embed",
  "encoding_format": "float"
}
```

#### Response

```json
{
  "object": "embedding",
  "embedding": [0.1, 0.2, -0.3, 0.4, ...],
  "model": "<embedding-model-name>"
}
```

### Rerank Endpoint

Rerank a list of documents according to their relevance to a query.

```http
POST /rerank
```

#### Request Body

```json
{
  "model": "<rerank-model-name>",
  "query": "How does AWS EC2 pricing work?",
  "documents": [
    "EC2 instances are billed by the hour with different rates for different instance types.",
    "AWS provides different pricing models including On-Demand, Reserved, and Spot instances.",
    "Cloud computing enables organizations to be more agile and reduce hardware costs."
  ],
  "top_n": 2
}
```

#### Response

```json
{
  "model": "<rerank-model-name>",
  "results": [
    {
      "document": "AWS provides different pricing models including On-Demand, Reserved, and Spot instances.",
      "index": 1,
      "relevance_score": 0.89
    },
    {
      "document": "EC2 instances are billed by the hour with different rates for different instance types.",
      "index": 0,
      "relevance_score": 0.76
    }
  ]
}
```

### Score Endpoint

Calculate the relevance score between two pieces of text.

```http
POST /score
```

#### Request Body

```json
{
  "model": "<score-model-name>",
  "text_1": "How does AWS EC2 pricing work?",
  "text_2": "EC2 instances are billed by the hour with different rates for different instance types."
}
```

#### Response

```json
{
  "model": "<score-model-name>",
  "score": 0.76
}
```

## Error Handling

All error responses follow this format:

```json
{
  "error": "Human-readable error message",
  "details": "Additional error details",
  "path": "/endpoint/path"
}
```

## Rate Limiting

Currently, the API does not implement rate limiting. Future versions will include rate limiting based on:

- IP address
- API key
- User/Client ID

## Versioning

The API follows semantic versioning (MAJOR.MINOR.PATCH). The current version can be found in the response from the root endpoint or the `/health` endpoint.

## Development and Testing

### Local Development

To run the API locally:

1. Navigate to the app directory:

   ```bash
   cd app
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Start the server:

   ```bash
   npm start
   ```

4. The server will be available at `http://localhost:8080`

### Docker Development

To build and run the API using Docker:

1. Build the image:

   ```bash
   docker build -t inference-app .
   ```

2. Run the container:

   ```bash
   docker run -p 8080:8080 -e VLLM_HOST=host.docker.internal -e MODEL_ID="<your-model-id>" inference-app
   ```

3. The server will be available at `http://localhost:8080`

### Testing with cURL

Examples of testing the API with cURL:

Health check:

```bash
curl http://localhost:8080/health
```

Root endpoint:

```bash
curl http://localhost:8080/
```

Models endpoint:

```bash
curl http://localhost:8080/v1/models
```

Chat completions:

```bash
curl -X POST \
  http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "<your-model-id>",
    "messages": [
      {"role": "user", "content": "Explain what AWS EC2 is in one paragraph."}
    ],
    "max_tokens": 100
  }'
```

## Changing Models

To change the model used by the inference solution:

1. Edit the `terraform.tfvars` file and modify the `model_id` parameter:

   ```hcl
   # vLLM Configuration
   model_id = "new-model/name-here"
   ```

2. Adjust `max_model_len` based on the context window size of your chosen model.

3. If needed, change the GPU instance type by modifying the `gpu_instance_type` parameter.

4. Increment the `ec2_instance_version` to force a replacement of the EC2 instance:

   ```hcl
   # Deployment version - increment to force replacement of EC2 instance
   ec2_instance_version = 3
   ```

5. Apply the changes with Terraform:

   ```bash
   terraform apply
   ```

This will create a new EC2 instance with the updated model configuration, while maintaining the same API endpoints and functionality.

## Future Enhancements

The API will be enhanced with the following features in future releases:

1. **Authentication and Authorization**:

   - API key management
   - OAuth 2.0 / OpenID Connect integration
   - Role-based access control

2. **Enhanced Inference Capabilities**:

   - Support for audio and vision models
   - Function calling support
   - Batched inference requests
   - Asynchronous inference processing

3. **Performance Features**:

   - Response caching
   - Request queuing
   - Throttling controls

4. **Monitoring and Logging**:

   - Detailed request/response logging
   - Performance metrics
   - Tracing support

5. **Documentation**:
   - OpenAPI (Swagger) specification
   - Interactive documentation
