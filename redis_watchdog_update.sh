#!/bin/bash

# Update service_watchdog.sh to include Redis monitoring
# This script modifies the existing service_watchdog.sh to add Redis-specific checks

# Path to the service watchdog script
WATCHDOG_SCRIPT="/opt/admin/scripts/service_watchdog.sh"

# Make a backup of the original script
cp $WATCHDOG_SCRIPT ${WATCHDOG_SCRIPT}.bak

# Add Redis to the SERVICES variable
sed -i 's/SERVICES="postgresql nginx express-app"/SERVICES="postgresql nginx express-app redis-server"/' $WATCHDOG_SCRIPT

# Add Redis-specific health check section at the end of the script
# Find the line before the script closing line
LINE_NUM=$(grep -n "# Log completion" $WATCHDOG_SCRIPT | cut -d: -f1)

# Insert Redis health check before the log completion section
sed -i "${LINE_NUM}i\\
# Redis-specific health check\\
if systemctl is-active --quiet redis-server; then\\
    echo \"Checking Redis health...\" >> \$LOG_FILE\\
    \\
    # Get Redis password if configured\\
    REDIS_PASSWORD=\$(grep \"^requirepass\" /etc/redis/redis.conf | cut -d \" \" -f2)\\
    \\
    # Create auth string with password if configured\\
    if [ -n \"\$REDIS_PASSWORD\" ]; then\\
        AUTH_PARAM=\"-a \$REDIS_PASSWORD\"\\
    else\\
        AUTH_PARAM=\"\"\\
    fi\\
    \\
    # Try to ping Redis\\
    if ! redis-cli \$AUTH_PARAM ping | grep -q PONG; then\\
        echo \"WARNING: Redis is running but not responding to ping!\" >> \$LOG_FILE\\
        \\
        # Get current restart count for redis-server\\
        service=\"redis-server\"\\
        current_line=\$(grep \"^\$service:\" \$RESTART_COUNT_FILE)\\
        current_count=\$(echo \$current_line | cut -d: -f2)\\
        last_date=\$(echo \$current_line | cut -d: -f3)\\
        today=\$(date +%Y%m%d)\\
        \\
        # Reset count if it's a new day\\
        if [ \"\$last_date\" != \"\$today\" ]; then\\
            current_count=0\\
            last_date=\$today\\
        fi\\
        \\
        # Check if we've exceeded max restarts\\
        if [ \$current_count -lt \$MAX_RESTARTS ]; then\\
            echo \"Attempting to restart Redis...\" >> \$LOG_FILE\\
            systemctl restart redis-server\\
            \\
            # Increment restart count\\
            new_count=\$((current_count + 1))\\
            sed -i \"s/^\$service:\$current_count:\$last_date/\$service:\$new_count:\$today/\" \$RESTART_COUNT_FILE\\
            \\
            # Send notification\\
            echo \"Redis was unresponsive and has been restarted on \$(hostname)\" | mail -s \"Redis Restart Notification\" \$ALERT_EMAIL\\
        else\\
            echo \"ERROR: Redis has been restarted \$current_count times today, exceeding limit of \$MAX_RESTARTS\" >> \$LOG_FILE\\
            echo \"Redis has failed \$current_count times today on \$(hostname)\" | mail -s \"Critical Redis Failure Alert\" \$ALERT_EMAIL\\
        fi\\
    else\\
        echo \"Redis is responding normally.\" >> \$LOG_FILE\\
    fi\\
fi\\
" $WATCHDOG_SCRIPT

echo "Service watchdog script updated to monitor Redis"
echo "Original script backed up at ${WATCHDOG_SCRIPT}.bak"
