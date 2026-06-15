#!/bin/bash
# One-command deploy to any Ubuntu VPS
set -e

REPO="https://github.com/qaaph-zyld/mastering_tool.git"
DOMAIN="${1:-}"

echo "=== Mastering Toolshop Deploy ==="

# Install Docker if missing
if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# Install Docker Compose if missing
if ! command -v docker-compose &>/dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Clone or pull
if [ -d "mastering_tool" ]; then
    cd mastering_tool && git pull
else
    git clone "$REPO" mastering_tool && cd mastering_tool
fi

# Build and run
docker-compose up --build -d

# Setup nginx + SSL if domain provided
if [ -n "$DOMAIN" ]; then
    echo "Setting up HTTPS for $DOMAIN..."
    sudo apt-get install -y nginx certbot python3-certbot-nginx
    sudo tee /etc/nginx/sites-available/mastering_tool <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    client_max_body_size 500M;
    location / {
        proxy_pass http://127.0.0.1:5050;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    sudo ln -sf /etc/nginx/sites-available/mastering_tool /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    sudo certbot --nginx -d "$DOMAIN" --agree-tos --non-interactive --email admin@$DOMAIN
    echo "HTTPS ready: https://$DOMAIN"
else
    echo "No domain provided. Access via http://$(curl -s ifconfig.me):5050"
fi

echo "=== Done ==="
echo "UI: http://$(curl -s ifconfig.me):5050"
