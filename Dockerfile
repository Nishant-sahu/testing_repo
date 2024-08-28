# Use the official Nginx image as a parent image
FROM nginx:latest

# Install necessary packages
RUN apt-get update && apt-get install -y \
    certbot \
    python3-certbot-nginx \
    openssl \
    luarocks \
    && rm -rf /var/lib/apt/lists/*

# Install Lua dependencies
RUN luarocks install lua-resty-redis

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy CAPTCHA verification script
COPY verify_captcha.lua /etc/nginx/verify_captcha.lua

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port 80 and 443
EXPOSE 80 443

# Set the entrypoint script to be executed
ENTRYPOINT ["/entrypoint.sh"]