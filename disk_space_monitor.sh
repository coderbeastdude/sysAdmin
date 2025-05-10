#!/bin/bash

# Disk Space Monitoring Script
# Purpose: Monitor disk space and clean up old files
# Recommended cron: 0 */4 * * * /path/to/disk_space_monitor.sh

# Configuration
ALERT_EMAIL="admin@example.com"
DISK_THRESHOLD=85
LOG_DIR="/var/log"
TEMP_DIR="/tmp"
LOG_RETENTION_DAYS=30
TEMP_RETENTION_DAYS=7
LOG_FILE="/var/log/disk_monitor.log"

echo "Disk Space Check: $(date)" >> $LOG_FILE

# Check disk space
for mount_point in / /var /home; do
    if [ -d "$mount_point" ]; then
        USAGE=$(df -h $mount_point | grep $mount_point | awk '{print $5}' | cut -d% -f1)
        echo "$mount_point usage: ${USAGE}%" >> $LOG_FILE
        
        if [ $USAGE -gt $DISK_THRESHOLD ]; then
            echo "WARNING: $mount_point disk usage is above threshold (${USAGE}%)" >> $LOG_FILE
            echo "Disk usage alert for $mount_point: ${USAGE}%" | mail -s "Disk Space Alert on $(hostname)" $ALERT_EMAIL
        fi
    fi
done

# Clean old log files
echo "Cleaning log files older than $LOG_RETENTION_DAYS days..." >> $LOG_FILE
find $LOG_DIR -type f -name "*.log.*" -mtime +$LOG_RETENTION_DAYS -delete
find $LOG_DIR -type f -name "*.gz" -mtime +$LOG_RETENTION_DAYS -delete

# Clean temporary files
echo "Cleaning temporary files older than $TEMP_RETENTION_DAYS days..." >> $LOG_FILE
find $TEMP_DIR -type f -mtime +$TEMP_RETENTION_DAYS -delete 2>/dev/null

# Clean npm cache if exists (for Node.js applications)
if command -v npm &> /dev/null; then
    echo "Cleaning npm cache..." >> $LOG_FILE
    npm cache clean --force >> $LOG_FILE 2>&1
fi

# PostgreSQL specific: Clean up old WAL files (if using archive_mode)
if [ -d "/var/lib/postgresql/*/archive" ]; then
    echo "Cleaning PostgreSQL WAL archives older than 7 days..." >> $LOG_FILE
    find /var/lib/postgresql/*/archive -type f -mtime +7 -delete 2>/dev/null
fi

echo "Disk space cleanup completed." >> $LOG_FILE