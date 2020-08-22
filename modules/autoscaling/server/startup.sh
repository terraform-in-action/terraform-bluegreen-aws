#!/bin/bash 
mkdir -p /var/www && cd /var/www
sudo tee /var/www/index.html > /dev/null <<EOF
${HTML}
EOF
python3 -m http.server 8080