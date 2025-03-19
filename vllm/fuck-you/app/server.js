const express = require('express');
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const app = express();
const port = process.env.PORT || 8080;
const httpsPort = process.env.HTTPS_PORT || 443;
const vllmPort = process.env.VLLM_PORT || 8000;
const vllmHost = process.env.VLLM_HOST || 'localhost';
const useHttps = process.env.USE_HTTPS === 'true';
const defaultTimeout = parseInt(process.env.DEFAULT_TIMEOUT_MS) || 60000; // Default 60 seconds
const maxTimeout = parseInt(process.env.MAX_TIMEOUT_MS) || 300000; // Max 5 minutes
const appVersion = '1.1.1'; // Updated version number

// Security headers middleware
app.use((req, res, next) => {
  // Add security headers
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  next();
});

// Middleware to parse JSON
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Calculate appropriate timeout based on request parameters
function calculateTimeout(req) {
  let timeout = defaultTimeout;
  
  // For chat/completions requests, scale timeout based on max_tokens
  if (req.body) {
    // Check if this is a request with max_tokens parameter
    if (req.body.max_tokens) {
      // Base timeout on tokens: 10ms per token plus base time for model loading
      const tokensTimeout = Math.min(maxTimeout, 30000 + (req.body.max_tokens * 10));
      timeout = Math.max(timeout, tokensTimeout);
      console.log(`Request with ${req.body.max_tokens} max_tokens, setting timeout to ${timeout}ms`);
    }
    
    // For larger context models, add additional time
    if (req.body.model && req.body.model.toLowerCase().includes('32b')) {
      // Add 50% more time for large models
      timeout = Math.min(maxTimeout, timeout * 1.5);
      console.log(`Large model detected (${req.body.model}), increasing timeout to ${timeout}ms`);
    }
    
    // Check if this is a streaming request
    if (req.body.stream === true) {
      // For streaming requests, use a higher timeout as they may continue for longer
      timeout = maxTimeout;
      console.log(`Streaming request detected, setting timeout to ${timeout}ms`);
    }
  }
  
  return Math.min(timeout, maxTimeout);
}

// Update the vLLM proxy function to handle vLLM being down better
function proxyToVLLM(path, req, res, transformResponse = null) {
  try {
    // Check vLLM status first
    const exec = require('child_process').exec;
    exec('/usr/local/bin/monitor-vllm.sh', (error, statusOutput, stderr) => {
      try {
        // If we can't even check status, that's a problem
        if (error) {
          console.error(`Failed to check vLLM status: ${error.message}`);
          return res.status(503).json({
            error: 'vLLM service unavailable',
            message: 'Unable to check vLLM status',
            status: 'loading',
            logs: 'Unable to check vLLM logs',
            retry_after: 30
          });
        }

        const vllmStatus = JSON.parse(statusOutput);
        
        // Check if GPU is enabled
        if (vllmStatus.gpu_enabled === false) {
          // When GPU is disabled, provide a clear message
          console.log('vLLM functionality is disabled because GPU support is turned off');
          return res.status(503).json({
            error: 'vLLM service disabled',
            message: 'GPU support is disabled. vLLM functionality is not available.',
            status: 'disabled',
            gpu_enabled: false
          });
        }
        
        // If vLLM API is not available but service is running, it's probably loading
        if (vllmStatus.api_status === "unavailable" && vllmStatus.service_status === "active") {
          console.log(`vLLM is still loading. Container: ${vllmStatus.container_status}, Service: ${vllmStatus.service_status}`);
          return res.status(503).json({
            error: 'vLLM service is loading',
            message: 'The model is still loading, please try again later',
            status: 'loading',
            logs: vllmStatus.last_logs,
            started_at: vllmStatus.started_at,
            retry_after: 30
          });
        }
        
        // If vLLM service is inactive, it may have crashed
        if (vllmStatus.service_status !== "active") {
          console.error(`vLLM service is not active: ${vllmStatus.service_status}`);
          return res.status(503).json({
            error: 'vLLM service is down',
            message: 'The inference engine is currently unavailable',
            status: 'down',
            logs: vllmStatus.last_logs,
            retry_after: 60
          });
        }
        
        // If we get here, the service is running but we can continue with the regular proxy
        // Determine if this is a GET or POST request
        const isGet = !req.body || Object.keys(req.body).length === 0;
        const method = isGet ? 'GET' : 'POST';
        
        // Calculate appropriate timeout for this request
        const timeout = calculateTimeout(req);
        
        // Set up the options for the request
        const options = {
          hostname: vllmHost,
          port: vllmPort,
          path: path,
          method: method,
          timeout: timeout,
          headers: {
            'Accept': 'application/json'
          }
        };

        let postData = null;
        if (!isGet) {
          postData = JSON.stringify(req.body);
          options.headers['Content-Type'] = 'application/json';
          options.headers['Content-Length'] = Buffer.byteLength(postData);
        }

        // Handle streaming responses
        const isStreaming = !isGet && req.body && req.body.stream === true;

        // Create the request to vLLM
        const vllmReq = http.request(options, (vllmRes) => {
          let data = '';
          
          // Set headers from vLLM response
          Object.keys(vllmRes.headers).forEach(key => {
            res.setHeader(key, vllmRes.headers[key]);
          });
          
          vllmRes.on('data', (chunk) => {
            // For streaming responses, send each chunk immediately
            if (isStreaming) {
              res.write(chunk);
            } else {
              data += chunk;
            }
          });
          
          vllmRes.on('end', () => {
            if (!isStreaming) {
              try {
                if (data) {
                  const responseData = JSON.parse(data);
                  if (transformResponse) {
                    // Apply custom transformation if provided
                    const transformedData = transformResponse(responseData);
                    res.status(vllmRes.statusCode).json(transformedData);
                  } else {
                    res.status(vllmRes.statusCode).json(responseData);
                  }
                } else {
                  res.status(vllmRes.statusCode).end();
                }
              } catch (error) {
                console.error(`Error parsing vLLM response: ${error}`);
                res.status(500).json({ 
                  error: 'Failed to parse vLLM response',
                  details: error.message
                });
              }
            } else {
              res.end();
            }
          });
        });

        vllmReq.on('error', (error) => {
          console.error(`Error calling vLLM service at ${path}: ${error}`);
          res.status(503).json({ 
            error: 'vLLM service unavailable', 
            details: error.message,
            path: path,
            retry_after: 10
          });
        });

        vllmReq.on('timeout', () => {
          vllmReq.destroy();
          res.status(504).json({ 
            error: 'vLLM service timeout', 
            message: 'The inference request took too long to process',
            path: path,
            retry_after: 30
          });
        });

        if (postData) {
          vllmReq.write(postData);
        }
        
        vllmReq.end();
        
      } catch (innerError) {
        console.error(`Error processing vLLM status: ${innerError}`);
        res.status(500).json({ 
          error: 'Internal server error', 
          details: innerError.message 
        });
      }
    });
  } catch (error) {
    console.error(`Error in proxy to vLLM: ${error}`);
    res.status(500).json({ 
      error: 'Internal server error', 
      details: error.message 
    });
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  // Use the server-side health check script to get detailed status
  const exec = require('child_process').exec;
  exec('/usr/local/bin/health-check.sh', (error, stdout, stderr) => {
    if (error) {
      console.error(`Health check script error: ${error}`);
      return res.status(503).json({ 
        status: 'error', 
        message: 'Health check script failed',
        version: appVersion
      });
    }
    
    try {
      // Parse the JSON output from the script
      const healthData = JSON.parse(stdout);
      
      // Set the appropriate HTTP status code
      if (healthData.status === 'error') {
        res.status(503);
      } else {
        res.status(200);
      }
      
      // Add version to the response
      healthData.version = appVersion;
      
      // Return the health check data
      res.json(healthData);
    } catch (e) {
      console.error(`Failed to parse health check output: ${e.message}`);
      res.status(503).json({ 
        status: 'error', 
        message: 'Invalid health check output',
        version: appVersion
      });
    }
  });
});

// vLLM status endpoint
app.get('/status', (req, res) => {
  const exec = require('child_process').exec;
  exec('/usr/local/bin/monitor-vllm.sh', (error, stdout, stderr) => {
    if (error) {
      console.error(`vLLM status check error: ${error}`);
      return res.status(500).json({
        error: 'Failed to check vLLM status',
        details: error.message
      });
    }
    
    try {
      // Parse the JSON output from the script
      const statusData = JSON.parse(stdout);
      
      // Add timestamps and additional info
      statusData.timestamp = new Date().toISOString();
      statusData.api_version = appVersion;
      statusData.model_id = process.env.MODEL_ID || 'Not specified';
      
      // Return the status data
      res.status(200).json(statusData);
    } catch (e) {
      console.error(`Failed to parse vLLM status output: ${e.message}`);
      res.status(500).json({
        error: 'Invalid vLLM status output',
        details: e.message
      });
    }
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.status(200).json({ 
    message: 'vLLM Inference API',
    timestamp: new Date().toISOString(),
    version: appVersion,
    modelInfo: process.env.MODEL_ID || 'Not specified'
  });
});

// vLLM models endpoint
app.get('/v1/models', (req, res) => {
  proxyToVLLM('/v1/models', req, res);
});

// Chat completions endpoint (OpenAI compatible)
app.post('/v1/chat/completions', (req, res) => {
  proxyToVLLM('/v1/chat/completions', req, res);
});

// Text completions endpoint (OpenAI compatible)
app.post('/v1/completions', (req, res) => {
  proxyToVLLM('/v1/completions', req, res);
});

// Tokenize endpoint
app.post('/tokenize', (req, res) => {
  proxyToVLLM('/tokenize', req, res);
});

// Detokenize endpoint
app.post('/detokenize', (req, res) => {
  proxyToVLLM('/detokenize', req, res);
});

// Version endpoint
app.get('/version', (req, res) => {
  proxyToVLLM('/version', req, res, (responseData) => {
    // Add proxy version to response
    return {
      ...responseData,
      proxy_version: appVersion
    };
  });
});

// Embeddings endpoint (OpenAI compatible)
app.post('/v1/embeddings', (req, res) => {
  proxyToVLLM('/v1/embeddings', req, res);
});

// Rerank endpoint
app.post('/rerank', (req, res) => {
  proxyToVLLM('/rerank', req, res);
});

// Rerank v1 endpoint
app.post('/v1/rerank', (req, res) => {
  proxyToVLLM('/v1/rerank', req, res);
});

// Rerank v2 endpoint
app.post('/v2/rerank', (req, res) => {
  proxyToVLLM('/v2/rerank', req, res);
});

// Score endpoint
app.post('/score', (req, res) => {
  proxyToVLLM('/score', req, res);
});

// Score v1 endpoint
app.post('/v1/score', (req, res) => {
  proxyToVLLM('/v1/score', req, res);
});

// SageMaker compatible endpoint
app.post('/invocations', (req, res) => {
  proxyToVLLM('/invocations', req, res);
});

// Start the server
if (useHttps) {
  try {
    // Check for certificate and key files
    const privateKey = fs.readFileSync('/etc/ssl/private/server.key', 'utf8');
    const certificate = fs.readFileSync('/etc/ssl/certs/server.crt', 'utf8');
    const credentials = { key: privateKey, cert: certificate };
    
    // Create HTTPS server
    const httpsServer = https.createServer(credentials, app);
    
    httpsServer.listen(httpsPort, () => {
      console.log(`vLLM Inference API proxy v${appVersion} running on HTTPS port ${httpsPort}`);
      console.log(`Also listening on HTTP port ${port} for health checks`);
      console.log(`Forwarding requests to vLLM at ${vllmHost}:${vllmPort}`);
    });
    
    // Also start HTTP server for health checks and redirect
    http.createServer((req, res) => {
      // Redirect HTTP to HTTPS except for health check endpoint
      if (req.url === '/health') {
        // Handle health check on HTTP
        app(req, res);
      } else {
        res.writeHead(301, { "Location": `https://${req.headers.host}${req.url}` });
        res.end();
      }
    }).listen(port, () => {
      console.log(`HTTP to HTTPS redirect running on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start HTTPS server:', error);
    console.log('Falling back to HTTP only mode');
    
    // Fall back to HTTP if HTTPS setup fails
    app.listen(port, () => {
      console.log(`vLLM Inference API proxy v${appVersion} running on HTTP port ${port}`);
      console.log(`Forwarding requests to vLLM at ${vllmHost}:${vllmPort}`);
    });
  }
} else {
  // HTTP only mode
  app.listen(port, () => {
    console.log(`vLLM Inference API proxy v${appVersion} running on HTTP port ${port}`);
    console.log(`Forwarding requests to vLLM at ${vllmHost}:${vllmPort}`);
  });
}
