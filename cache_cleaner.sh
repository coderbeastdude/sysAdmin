#!/bin/bash

# Cache Cleaner Script
# Purpose: Clean application caches to free up memory and disk space
# Recommended cron: 0 3 * * * /path/to/cache_cleaner.sh

# Configuration
LOG_FILE="/var/log/cache_cleaner.log"
ALERT_EMAIL="admin@example.com"
NODE_APP_DIR="/var/www/express-app"
REACT_APP_DIR="/var/www/react-app"
NGINX_CACHE_DIR="/var/cache/nginx"
BROWSER_CACHE_MAX_AGE=604800  # 1 week in seconds

# Log start
echo "Cache cleaning started: $(date)" >> $LOG_FILE

# Clean Node.js/Express cache
if [ -d "$NODE_APP_DIR" ]; then
    echo "Cleaning Node.js/Express cache..." >> $LOG_FILE
    
    # Remove node_modules/.cache if it exists
    if [ -d "$NODE_APP_DIR/node_modules/.cache" ]; then
        du -sh "$NODE_APP_DIR/node_modules/.cache" >> $LOG_FILE
        rm -rf "$NODE_APP_DIR/node_modules/.cache"
        echo "Removed Node.js cache directory." >> $LOG_FILE
    fi
    
    # Clear any application-specific cache directories
    if [ -d "$NODE_APP_DIR/cache" ]; then
        du -sh "$NODE_APP_DIR/cache" >> $LOG_FILE
        rm -rf "$NODE_APP_DIR/cache/*"
        echo "Cleared application cache directory." >> $LOG_FILE
    fi
fi

# Clean React build cache
if [ -d "$REACT_APP_DIR" ]; then
    echo "Cleaning React build cache..." >> $LOG_FILE
    
    # Remove node_modules/.cache if it exists
    if [ -d "$REACT_APP_DIR/node_modules/.cache" ]; then
        du -sh "$REACT_APP_DIR/node_modules/.cache" >> $LOG_FILE
        rm -rf "$REACT_APP_DIR/node_modules/.cache"
        echo "Removed React cache directory." >> $LOG_FILE
    fi
fi

# Clean Nginx cache
if [ -d "$NGINX_CACHE_DIR" ]; then
    echo "Cleaning Nginx cache..." >> $LOG_FILE
    du -sh "$NGINX_CACHE_DIR" >> $LOG_FILE
    
    # Only remove files, not directories
    find "$NGINX_CACHE_DIR" -type f -delete
    echo "Cleared Nginx cache files." >> $LOG_FILE
fi

# Update Nginx cache control headers for static assets
if [ -f "/etc/nginx/conf.d/cache-control.conf" ]; then
    echo "Updating Nginx cache control settings..." >> $LOG_FILE
    
    # Create or update cache control configuration
    cat > /etc/nginx/conf.d/cache-control.conf << EOF
# Cache control settings for static assets
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires ${BROWSER_CACHE_MAX_AGE}s;
    add_header Cache-Control "public, max-age=${BROWSER_CACHE_MAX_AGE}";
}
EOF
    
    # Test Nginx configuration
    nginx -t >> $LOG_FILE 2>&1
    if [ $? -eq 0 ]; then
        # Reload Nginx if configuration is valid
        systemctl reload nginx
        echo "Updated Nginx cache control settings and reloaded configuration." >> $LOG_FILE
    else
        echo "ERROR: Invalid Nginx configuration. Changes not applied." >> $LOG_FILE
        echo "Nginx configuration error on $(hostname)" | mail -s "Nginx Configuration Alert" $ALERT_EMAIL
    fi
fi

# Clean system page cache (use with caution)
# Uncomment if needed, but be aware this can temporarily impact performance
# echo "Cleaning system page cache..." >> $LOG_FILE
# sync; echo 1 > /proc/sys/vm/drop_caches

# Log completion and disk space saved
echo "Cache cleaning completed: $(date)" >> $LOG_FILE
echo "Current disk usage:" >> $LOG_FILE
df -h / >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE