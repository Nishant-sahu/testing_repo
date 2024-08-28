FROM openresty/openresty:alpine

# Install necessary packages
RUN apk add --no-cache openssl

# Install Lua dependencies
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-redis

# Copy custom Nginx configuration
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Copy CAPTCHA verification script
COPY verify_captcha.lua /etc/nginx/verify_captcha.lua

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port 80 and 443
EXPOSE 80 443

# Set the entrypoint script to be executed
ENTRYPOINT ["/entrypoint.sh"]