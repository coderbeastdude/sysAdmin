#!/bin/bash

# Nginx Hardening Script
# Purpose: Implement optimized buffer settings, timeouts, and caching directives for Nginx
# Based on the configurations from the project notes

# Configuration
LOG_FILE="/var/log/nginx_hardening.log"
NGINX_CONF="/etc/nginx/nginx.conf"
INCLUDES_DIR="/etc/nginx/includes"
SITES_AVAILABLE="/etc/nginx/sites-available"
DEFAULT_SITE="default"

# Log start
echo "Nginx hardening started: $(date)" > $LOG_FILE

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "Nginx not installed. Installing..." >> $LOG_FILE
    apt-get update
    apt-get install -y nginx
fi

# Create includes directory if it doesn't exist
if [ ! -d "$INCLUDES_DIR" ]; then
    echo "Creating Nginx includes directory..." >> $LOG_FILE
    mkdir -p $INCLUDES_DIR
fi

# Backup original Nginx configuration
echo "Backing up original Nginx configuration..." >> $LOG_FILE
cp $NGINX_CONF ${NGINX_CONF}.bak.$(date +"%Y%m%d")

# Update the main Nginx configuration with performance directives
echo "Updating main Nginx configuration..." >> $LOG_FILE
grep -q "worker_rlimit_nofile" $NGINX_CONF || sed -i '/^http {/i worker_rlimit_nofile 30000;' $NGINX_CONF
grep -q "worker_priority" $NGINX_CONF || sed -i '/^http {/i worker_priority -10;' $NGINX_CONF
grep -q "timer_resolution" $NGINX_CONF || sed -i '/^http {/i timer_resolution 100ms;' $NGINX_CONF
grep -q "pcre_jit" $NGINX_CONF || sed -i '/^http {/i pcre_jit on;' $NGINX_CONF

# Update events context
echo "Updating events context..." >> $LOG_FILE
if grep -q "events {" $NGINX_CONF; then
    # Check if we need to update the existing events block
    if ! grep -q "worker_connections 4096" $NGINX_CONF; then
        sed -i '/events {/,/}/c\
events {\
    worker_connections 4096;\
    accept_mutex on;\
    accept_mutex_delay 200ms;\
    use epoll;\
}' $NGINX_CONF
    fi
fi

# Create the basic_settings.conf file
echo "Creating basic_settings.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/basic_settings.conf << 'EOF'
##
# BASIC SETTINGS
##
charset utf-8;
sendfile on;
sendfile_max_chunk 512k;
tcp_nopush on;
tcp_nodelay on;
server_tokens off;
more_clear_headers 'Server';
more_clear_headers 'X-Powered';
server_name_in_redirect off;
server_names_hash_bucket_size 64;
variables_hash_max_size 2048;
types_hash_max_size 2048;
include /etc/nginx/mime.types;
default_type application/octet-stream;
EOF

# Create the buffers.conf file
echo "Creating buffers.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/buffers.conf << 'EOF'
##
# BUFFERS
##
client_body_buffer_size 256k;
client_body_in_file_only off;
client_header_buffer_size 64k;
# client max body size - reduce size to 16m after setting up site
# Large value is to allow theme, plugins or asset uploading.
client_max_body_size 100m;
connection_pool_size 512;
directio 4m;
ignore_invalid_headers on;
large_client_header_buffers 8 64k;
output_buffers 8 256k;
postpone_output 1460;
request_pool_size 32k;
EOF

# Create the timeouts.conf file
echo "Creating timeouts.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/timeouts.conf << 'EOF'
##
# TIMEOUTS
##
keepalive_timeout 5;
keepalive_requests 500;
lingering_time 20s;
lingering_timeout 5s;
keepalive_disable msie6;
reset_timedout_connection on;
send_timeout 15s;
client_header_timeout 8s;
client_body_timeout 10s;
EOF

# Create the file_handle_cache.conf file
echo "Creating file_handle_cache.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/file_handle_cache.conf << 'EOF'
##
# FILE HANDLE CACHE
##
open_file_cache max=50000 inactive=60s;
open_file_cache_valid 120s;
open_file_cache_min_uses 2;
open_file_cache_errors off;
EOF

# Create the gzip.conf file
echo "Creating gzip.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/gzip.conf << 'EOF'
##
# GZIP
##
gzip on;
gzip_vary on;
gzip_disable "MSIE [1-6]\.";
gzip_static on;
gzip_min_length 1400;
gzip_buffers 32 8k;
gzip_http_version 1.0;
gzip_comp_level 5;
gzip_proxied any;
gzip_types text/plain text/css text/xml application/javascript application/x-javascript application/xml application/xml+rss application/ecmascript application/json image/svg+xml;
EOF

# Create brotli.conf if brotli module is installed
echo "Checking for Brotli module..." >> $LOG_FILE
if dpkg -l | grep -q "libnginx-mod-http-brotli"; then
    echo "Creating brotli.conf..." >> $LOG_FILE
    cat > $INCLUDES_DIR/brotli.conf << 'EOF'
##
# BROTLI
##
brotli on;
brotli_comp_level 6;
brotli_static on;
brotli_types application/atom+xml application/javascript application/json application/rss+xml application/vnd.ms-fontobject application/x-font-opentype application/x-font-truetype application/x-font-ttf application/x-javascript application/xhtml+xml application/xml font/eot font/opentype font/otf font/truetype image/svg+xml image/vnd.microsoft.icon image/x-icon image/x-win-bitmap text/css text/javascript text/plain text/xml;
EOF
else
    echo "Brotli module not installed. Skipping brotli configuration." >> $LOG_FILE
fi

# Create the browser_caching.conf file
echo "Creating browser_caching.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/browser_caching.conf << 'EOF'
location ~* \.(webp|3gp|gif|jpg|jpeg|png|ico|wmv|avi|asf|asx|mpg|mpeg|mp4|pls|mp3|mid|wav|swf|flv|exe|zip|tar|rar|gz|tgz|bz2|uha|7z|doc|docx|xls|xlsx|pdf|iso)$ {
    add_header Cache-Control "public, no-transform";
    access_log off;
    expires 365d;
}
location ~* \.(js)$ {
    add_header Cache-Control "public, no-transform";
    access_log off;
    expires 30d;
}
location ~* \.(css)$ {
    add_header Cache-Control "public, no-transform";
    access_log off;
    expires 30d;
}
location ~* \.(eot|svg|ttf|woff|woff2)$ {
    add_header Cache-Control "public, no-transform";
    access_log off;
    expires 30d;
}
EOF

# Create the fastcgi_optimize.conf file
echo "Creating fastcgi_optimize.conf..." >> $LOG_FILE
cat > $INCLUDES_DIR/fastcgi_optimize.conf << 'EOF'
fastcgi_connect_timeout 60;
fastcgi_send_timeout 180;
fastcgi_read_timeout 180;
fastcgi_buffer_size 512k;
fastcgi_buffers 512 16k;
fastcgi_busy_buffers_size 1m;
fastcgi_temp_file_write_size 4m;
fastcgi_max_temp_file_size 4m;
fastcgi_intercept_errors on;
EOF

# Update HTTP context in main Nginx config to include our optimization files
echo "Updating http context in the main Nginx configuration..." >> $LOG_FILE
grep -q "include /etc/nginx/includes/basic_settings.conf;" $NGINX_CONF || sed -i '/^http {/a include /etc/nginx/includes/basic_settings.conf;' $NGINX_CONF
grep -q "include /etc/nginx/includes/buffers.conf;" $NGINX_CONF || sed -i '/^http {/a include /etc/nginx/includes/buffers.conf;' $NGINX_CONF
grep -q "include /etc/nginx/includes/timeouts.conf;" $NGINX_CONF || sed -i '/^http {/a include /etc/nginx/includes/timeouts.conf;' $NGINX_CONF
grep -q "include /etc/nginx/includes/gzip.conf;" $NGINX_CONF || sed -i '/^http {/a include /etc/nginx/includes/gzip.conf;' $NGINX_CONF
grep -q "include /etc/nginx/includes/file_handle_cache.conf;" $NGINX_CONF || sed -i '/^http {/a include /etc/nginx/includes/file_handle_cache.conf;' $NGINX_CONF

if dpkg -l | grep -q "libnginx-mod-http-brotli"; then
    grep -q "include /etc/nginx/includes/brotli.conf;" $NGINX_CONF || sed -i '/^http {/a include /etc/nginx/includes/brotli.conf;' $NGINX_CONF
fi

# Function to update server blocks
update_server_block() {
    local site_conf=$1
    local site_name=$(basename $site_conf)
    
    echo "Updating server block for $site_name..." >> $LOG_FILE
    
    # First check for existence of PHP location block
    if grep -q "location ~ \\.php\$" $site_conf; then
        # Check if fastcgi_optimize.conf is already included
        if ! grep -q "include /etc/nginx/includes/fastcgi_optimize.conf;" $site_conf; then
            # Add fastcgi_optimize.conf include
            sed -i '/location ~ \\.php\$ {/,/}/s/fastcgi_pass [^;]*;/&\n        include \/etc\/nginx\/includes\/fastcgi_optimize.conf;/' $site_conf
        fi
    fi
    
    # Check if browser_caching.conf is already included
    if ! grep -q "include /etc/nginx/includes/browser_caching.conf;" $site_conf; then
        # Add browser_caching.conf include before the end of the server block
        sed -i '/server {/,/}/s/}$/    include \/etc\/nginx\/includes\/browser_caching.conf;\n}/' $site_conf
    fi
}

# Update all server block configurations
echo "Updating server block configurations..." >> $LOG_FILE
for site_conf in $SITES_AVAILABLE/*; do
    if [ -f "$site_conf" ]; then
        update_server_block "$site_conf"
    fi
done

# Check Nginx config for syntax errors
echo "Checking Nginx configuration..." >> $LOG_FILE
if nginx -t >> $LOG_FILE 2>&1; then
    echo "Nginx configuration is valid, reloading Nginx..." >> $LOG_FILE
    systemctl reload nginx
    echo "Nginx reloaded successfully." >> $LOG_FILE
else
    echo "ERROR: Nginx configuration is invalid. Please check the logs." >> $LOG_FILE
fi

# Open file limit configuration
echo "Checking open file limits..." >> $LOG_FILE
NGINX_PID=$(ps aux | grep 'nginx: master process' | grep -v grep | awk '{print $2}')
if [ -n "$NGINX_PID" ]; then
    echo "Current Nginx open file limits:" >> $LOG_FILE
    cat /proc/$NGINX_PID/limits | grep "open files" >> $LOG_FILE
fi

echo "Nginx hardening completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE

# Show a summary to the user
echo "Nginx hardening has been completed."
echo "The following optimizations have been applied:"
echo "- Main context performance directives"
echo "- Events context optimizations"
echo "- Buffer settings"
echo "- Timeout configurations"
echo "- Browser caching directives"
echo "- Gzip compression settings"
if dpkg -l | grep -q "libnginx-mod-http-brotli"; then
    echo "- Brotli compression settings"
fi
echo "- File handle cache settings"
echo "- FastCGI optimizations"
echo
echo "A log of the changes has been written to: $LOG_FILE"
echo
echo "To check the Nginx configuration, run: sudo nginx -t"
echo "To reload Nginx, run: sudo systemctl reload nginx"
