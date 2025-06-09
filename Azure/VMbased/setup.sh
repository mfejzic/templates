#!/bin/bash

set -e

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y python3 python3-pip nginx ufw

# Copy app files
mkdir -p /var/www/myapp/templates
cp /home/azureuser/vmbased/app.py /var/www/myapp/
cp /home/azureuser/vmbased/requirements.txt /var/www/myapp/
cp /home/azureuser/vmbased/templates/index.html /var/www/myapp/templates/
cp /home/azureuser/vmbased/init_db.py /var/www/myapp/

cd /var/www/myapp

# Install Python packages
pip3 install -r requirements.txt

# Initialize database schema
python3 /var/www/myapp/init_db.py

# Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/myapp.service
[Unit]
Description=Flask App
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/python3 /var/www/myapp/app.py
Restart=always
EnvironmentFile=/etc/environment

[Install]
WantedBy=multi-user.target
EOF

# Reload and start the Flask app
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable myapp
systemctl start myapp

# Configure NGINX
cat <<EOF | sudo tee /etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;  # Your app runs on port 80
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# Configure Firewall
ufw allow 'Nginx Full'
ufw --force enable
