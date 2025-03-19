echo "===== Setting up TLS certificate ====="
  
# Install Certbot and dependencies
apt-get install -y certbot python3-certbot-nginx

# Setup a simple self-signed certificate initially
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/server.key \
  -out /etc/ssl/certs/server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:infer.${domain_name}" || true

chmod 600 /etc/ssl/private/server.key

# Create basic NGINX config for Certbot
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80;
    server_name infer.${domain_name};
    location / {
        proxy_pass http://localhost:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout ${max_proxy_timeout}s;
        proxy_connect_timeout ${default_proxy_timeout}s;
        proxy_send_timeout ${max_proxy_timeout}s;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Restart NGINX
systemctl restart nginx || true

# Request Let's Encrypt certificate
# Don't fail the script if this fails, we'll fall back to self-signed
certbot --nginx -d infer.${domain_name} --non-interactive --agree-tos -m ${admin_email} --redirect || true

# Setup renewal cron job
echo "0 3 * * * certbot renew --quiet" > /etc/cron.d/certbot-renew

# Use Let's Encrypt certificates for our API if available
if [ -d "/etc/letsencrypt/live/infer.${domain_name}" ]; then
  ln -sf /etc/letsencrypt/live/infer.${domain_name}/privkey.pem /etc/ssl/private/server.key
  ln -sf /etc/letsencrypt/live/infer.${domain_name}/fullchain.pem /etc/ssl/certs/server.crt
fi

echo "===== Setting up optimized NGINX configuration ====="

# Configure NGINX for inference API with optimized timeout settings
cat > /etc/nginx/sites-available/inference-api << EOF
# Define proxy timeout settings
proxy_connect_timeout ${default_proxy_timeout}s;
proxy_send_timeout ${max_proxy_timeout}s;
proxy_read_timeout ${max_proxy_timeout}s;

# Define server block for HTTP to HTTPS redirection
server {
    listen 80;
    server_name infer.${domain_name};
    
    # Allow health check endpoint via HTTP
    location /health {
        proxy_pass http://localhost:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# Define main server block for HTTPS
server {
    listen 443 ssl;
    server_name infer.${domain_name};
    
    # SSL configuration
    ssl_certificate /etc/ssl/certs/server.crt;
    ssl_certificate_key /etc/ssl/private/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self';" always;
    
    # Buffer settings for large responses
    proxy_buffer_size 16k;
    proxy_buffers 32 16k;
    proxy_busy_buffers_size 32k;

    # Route all traffic to the API proxy
    location / {
        proxy_pass http://localhost:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Default timeout for API endpoints
        proxy_read_timeout ${default_proxy_timeout}s;
        
        # Higher timeouts for inference endpoints
        location ~ ^/v1/(chat/completions|completions) {
            proxy_pass http://localhost:${app_port};
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_read_timeout ${max_proxy_timeout}s;
            
            # Headers for tracking timeouts
            add_header X-Timeout-Config "extended";
            
            # Additional configuration for streaming
            proxy_buffering off;
            proxy_cache off;
            
            # Enable keepalive for long connections
            proxy_http_version 1.1;
            proxy_set_header Connection "keep-alive";
        }
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        
        # Short timeout for health checks
        proxy_read_timeout 5s;
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
    }
}
EOF

# Enable the configuration
ln -sf /etc/nginx/sites-available/inference-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Optimize NGINX server settings
cat > /etc/nginx/conf.d/optimize.conf << EOF
# NGINX performance optimization
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    client_body_timeout 30s;
    client_header_timeout 30s;
    send_timeout 60s;
    
    client_max_body_size 50M;
    
    open_file_cache max=1000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
    
    gzip on;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF

# Test the configuration
nginx -t

# If successful, reload NGINX
if [ $? -eq 0 ]; then
  systemctl reload nginx
  echo "NGINX configuration updated successfully"
else
  echo "NGINX configuration error, reverting to default configuration"
  # Revert to simpler configuration
  cat > /etc/nginx/sites-available/inference-api << EOF
server {
    listen 80;
    server_name infer.${domain_name};
    
    location / {
        proxy_pass http://localhost:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout ${max_proxy_timeout}s;
        proxy_connect_timeout ${default_proxy_timeout}s;
        proxy_send_timeout ${max_proxy_timeout}s;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/inference-api /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  systemctl reload nginx
fi