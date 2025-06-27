#!/bin/bash
set -euo pipefail

# Credentials injected by Terraform
N8N_BASIC_AUTH_USER="__N8N_USER__"
N8N_BASIC_AUTH_PASSWORD="__N8N_PASSWORD__"
# Ensure all files are created in the user's home directory
cd "$HOME"

# Attempt to get public IP from instance metadata
# This might vary based on cloud provider, adjust if necessary for OCI.
# For OCI, this is a common way: curl -H 'Authorization: Bearer Oracle' -L http://169.254.169.254/opc/v1/vnics/ | jq -r '.[0].publicIp'
# However, jq might not be installed. Let's try a simpler curl for public IP if available directly.
# Fallback if metadata service is not available or IP not found easily without jq
PUBLIC_IP=$(curl -s ifconfig.me || curl -s api.ipify.org || echo "localhost")

# Escape special characters
ESCAPED_USER=$(printf '%s' "$N8N_BASIC_AUTH_USER" | sed -e 's/[\/&|]/\\&/g')
ESCAPED_PASSWORD=$(printf '%s' "$N8N_BASIC_AUTH_PASSWORD" | sed -e 's/[\/&|]/\\&/g')

# Install Docker, Docker Compose, and Nginx
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release nginx jq
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
if [ -n "${USER-}" ]; then
    sudo usermod -aG docker "$USER"
fi
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Generate self-signed SSL certificate for Nginx
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/n8n.key -out /etc/nginx/ssl/n8n.crt \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=$PUBLIC_IP"

# Create Nginx configuration for n8n
cat <<EOF_NGINX | sudo tee /etc/nginx/sites-available/n8n > /dev/null
server {
    listen 80;
    server_name $PUBLIC_IP _; # Listen on public IP and default server
    return 301 https://\$host\$request_uri; # Redirect HTTP to HTTPS
}

server {
    listen 443 ssl http2;
    server_name $PUBLIC_IP _; # Listen on public IP and default server

    ssl_certificate /etc/nginx/ssl/n8n.crt;
    ssl_certificate_key /etc/nginx/ssl/n8n.key;

    # Recommendations from https://github.com/n8n-io/n8n-docs/blob/master/hosting/server-setup/reverse-proxy.md
    # and https://mozilla.github.io/server-side-tls/ssl-config-generator/
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # HSTS (optional, but recommended)
    # add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # OCSP Stapling (optional, but recommended for CA-signed certs)
    # ssl_stapling on;
    # ssl_stapling_verify on;
    # resolver 1.1.1.1 1.0.0.1 valid=300s; # Use your preferred DNS resolvers
    # resolver_timeout 5s;

    location / {
        proxy_pass http://127.0.0.1:5678; # n8n running on localhost port 5678
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off; # Recommended for n8n SSE
        proxy_set_header Upgrade \$http_upgrade; # Required for WebSockets
        proxy_set_header Connection "Upgrade"; # Required for WebSockets
    }
}
EOF_NGINX

# Enable the Nginx site and restart Nginx
sudo ln -sfn /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
sudo rm -f /etc/nginx/sites-enabled/default # Remove default Nginx site
sudo nginx -t # Test Nginx configuration
sudo systemctl restart nginx

# Create Docker Compose file with injected credentials
# Note: N8N_HOST should be the public domain/IP n8n is accessed through.
# N8N_PROTOCOL should be https.
cat <<EOF_COMPOSE | sudo tee docker-compose.yml > /dev/null
services:
  n8n:
    image: n8nio/n8n
    restart: unless-stopped
    container_name: n8n
    # Port 5678 is now only exposed to the host, not publicly. Nginx handles public access.
    # ports:
    #  - "127.0.0.1:5678:5678" # Optional: explicitly bind to localhost if needed for Nginx proxy
    user: "1000:1000" # Run n8n as non-root user (assuming n8n image uses UID/GID 1000 for node user)
    environment:
      - GENERIC_TIMEZONE=Europe/Madrid
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=$ESCAPED_USER
      - N8N_BASIC_AUTH_PASSWORD=$ESCAPED_PASSWORD
      - N8N_SECURE_COOKIE=true # Set to true for HTTPS
      - N8N_PROTOCOL=https # n8n needs to know it's behind HTTPS
      - N8N_HOST=$PUBLIC_IP # n8n needs to know its public host
      # WEBHOOK_URL: https://$PUBLIC_IP/ # For older n8n versions, might be needed if N8N_HOST isn't enough
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF_COMPOSE

# Prepare volume and start container
mkdir -p n8n_data
# The n8n container runs as user 1000, so data directory should be owned by this user
sudo chown -R 1000:1000 n8n_data
sudo docker-compose -p n8n up -d

echo "---------------------------------------------------------------------------"
echo "n8n installation complete."
echo "Access n8n at: https://$PUBLIC_IP"
echo "IMPORTANT: You are using a self-signed SSL certificate."
echo "Browsers will show a warning. For production, replace"
echo "/etc/nginx/ssl/n8n.key and /etc/nginx/ssl/n8n.crt with your own"
echo "SSL certificate and key, then restart Nginx: sudo systemctl restart nginx"
echo "---------------------------------------------------------------------------"
