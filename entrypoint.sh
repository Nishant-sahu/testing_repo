#!/bin/bash

# Function to generate SSL certificate
generate_ssl_cert() {
    local domain=$1
    certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email admin@example.com
}

# Function to update Nginx SSL configuration
update_ssl_config() {
    local domain=$1
    sed -i "s|/etc/letsencrypt/live/default/|/etc/letsencrypt/live/$domain/|g" /etc/nginx/nginx.conf
}

# Main execution
if [ ! -f /etc/letsencrypt/live/default/fullchain.pem ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/letsencrypt/live/default/privkey.pem \
        -out /etc/letsencrypt/live/default/fullchain.pem \
        -subj "/CN=default"
fi

# Start Nginx
nginx -g "daemon off;" &

# Wait for Nginx to start
sleep 5

# Monitor for new domain connections and generate certificates
while true; do
    new_domains=$(nginx -T 2>/dev/null | grep "ssl_certificate" | awk '{print $2}' | sort | uniq)
    for domain in $new_domains; do
        if [ ! -f "$domain" ]; then
            domain_name=$(basename $(dirname "$domain"))
            if [ "$domain_name" != "default" ]; then
                generate_ssl_cert "$domain_name"
                update_ssl_config "$domain_name"
                nginx -s reload
            fi
        fi
    done
    sleep 60
done