#!/bin/bash

# Redis Security Configuration Script
# Purpose: Secure Redis installation and monitor performance

# Configuration
LOG_FILE="/var/log/redis_security.log"
ALERT_EMAIL="admin@example.com"
REDIS_CONF="/etc/redis/redis.conf"
REDIS_PASSWORD=$(openssl rand -base64 24)  # Generate random password
MAX_MEMORY_THRESHOLD=80  # Alert if Redis is using more than 80% of configured memory

# Log start
echo "Redis security setup: $(date)" > $LOG_FILE

# Ensure Redis is installed
if ! command -v redis-server &> /dev/null; then
    echo "Redis not installed. Installing..." >> $LOG_FILE
    apt-get update
    apt-get install -y redis-server
fi

# Backup original config
cp $REDIS_CONF ${REDIS_CONF}.bak
echo "Created backup at ${REDIS_CONF}.bak" >> $LOG_FILE

# Configure Redis security settings
echo "Configuring Redis security..." >> $LOG_FILE

# Bind to localhost only to prevent external access
sed -i 's/^# bind 127.0.0.1/bind 127.0.0.1/' $REDIS_CONF

# Set password authentication
if grep -q "^requirepass" $REDIS_CONF; then
    sed -i "s/^requirepass.*/requirepass $REDIS_PASSWORD/" $REDIS_CONF
else
    echo "requirepass $REDIS_PASSWORD" >> $REDIS_CONF
fi

# Disable potentially dangerous commands
echo "Protected-mode yes" >> $REDIS_CONF
echo "rename-command FLUSHALL \"\"" >> $REDIS_CONF
echo "rename-command FLUSHDB \"\"" >> $REDIS_CONF
echo "rename-command DEBUG \"\"" >> $REDIS_CONF
echo "rename-command CONFIG \"\"" >> $REDIS_CONF

# Setup reasonable memory limits to prevent DoS
echo "maxmemory 256mb" >> $REDIS_CONF  # Adjust based on your server capacity
echo "maxmemory-policy allkeys-lru" >> $REDIS_CONF  # Evict keys when memory is full

# Disable persistence to disk if not needed (enables faster performance)
# Comment out if you need persistence
sed -i 's/^save/# save/' $REDIS_CONF

# Enable slow log for performance monitoring
echo "slowlog-log-slower-than 10000" >> $REDIS_CONF  # Log queries slower than 10ms
echo "slowlog-max-len 128" >> $REDIS_CONF  # Store up to 128 slowlog entries

# Restart Redis to apply changes
systemctl restart redis-server

# Verify Redis is running
if systemctl is-active --quiet redis-server; then
    echo "Redis is running with new security settings" >> $LOG_FILE
else
    echo "ERROR: Redis failed to start after configuration changes!" >> $LOG_FILE
    echo "Redis failed to start on $(hostname) after security configuration" | mail -s "Redis Security Alert" $ALERT_EMAIL
    exit 1
fi

# Save password for admin
echo "Redis password has been set to: $REDIS_PASSWORD" >> $LOG_FILE
echo "Redis has been secured on $(hostname). Password: $REDIS_PASSWORD" | mail -s "Redis Security Configuration" $ALERT_EMAIL

echo "Redis security configuration completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE

# Add this script to cron to run weekly
CRON_FILE="/etc/cron.d/redis-monitor"
echo "# Auto-generated Redis security monitor cron" > $CRON_FILE
echo "0 2 * * 0 root /opt/admin/scripts/redis_monitor.sh > /dev/null 2>&1" >> $CRON_FILE
echo "0 0 */7 * * root /opt/admin/scripts/redis_security.sh > /dev/null 2>&1" >> $CRON_FILE
chmod 644 $CRON_FILE

echo "Added weekly security check to cron" >> $LOG_FILE
