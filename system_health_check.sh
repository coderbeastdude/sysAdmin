#!/bin/bash

# System Health Check Script
# Purpose: Monitor CPU, memory, disk usage, and load averages
# Recommended cron: */15 * * * * /path/to/system_health_check.sh

# Configuration
ALERT_EMAIL="admin@example.com"
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
LOAD_THRESHOLD=$(nproc)  # Number of CPU cores

LOG_FILE="/var/log/system_health_check.log"
TEMP_FILE=$(mktemp)

# Timestamp
echo "System Health Check: $(date)" >> $TEMP_FILE

# Check CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1)
echo "CPU Usage: ${CPU_USAGE}%" >> $TEMP_FILE
if [ $CPU_USAGE -gt $CPU_THRESHOLD ]; then
    echo "WARNING: High CPU usage detected!" >> $TEMP_FILE
    ALERT=1
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
echo "Memory Usage: ${MEMORY_USAGE}%" >> $TEMP_FILE
if [ $MEMORY_USAGE -gt $MEMORY_THRESHOLD ]; then
    echo "WARNING: High memory usage detected!" >> $TEMP_FILE
    ALERT=1
fi

# Check disk usage
DISK_USAGE=$(df -h / | grep / | awk '{print $5}' | cut -d% -f1)
echo "Disk Usage: ${DISK_USAGE}%" >> $TEMP_FILE
if [ $DISK_USAGE -gt $DISK_THRESHOLD ]; then
    echo "WARNING: High disk usage detected!" >> $TEMP_FILE
    ALERT=1
fi

# Check system load
LOAD=$(uptime | awk -F'[a-z]:' '{ print $2}' | awk -F',' '{print $1}' | tr -d ' ')
LOAD_ROUNDED=$(echo $LOAD | cut -d. -f1)
echo "System Load: $LOAD (Threshold: $LOAD_THRESHOLD)" >> $TEMP_FILE
if (( $(echo "$LOAD > $LOAD_THRESHOLD" | bc -l) )); then
    echo "WARNING: High system load detected!" >> $TEMP_FILE
    ALERT=1
fi

# Check PostgreSQL status
if systemctl is-active --quiet postgresql; then
    echo "PostgreSQL: Running" >> $TEMP_FILE
else
    echo "WARNING: PostgreSQL is not running!" >> $TEMP_FILE
    ALERT=1
fi

# Check Node.js/Express service status (adjust service name as needed)
if systemctl is-active --quiet express-app; then
    echo "Express App: Running" >> $TEMP_FILE
else
    echo "WARNING: Express application is not running!" >> $TEMP_FILE
    ALERT=1
fi

# Check Nginx/web server status
if systemctl is-active --quiet nginx; then
    echo "Web Server: Running" >> $TEMP_FILE
else
    echo "WARNING: Web server is not running!" >> $TEMP_FILE
    ALERT=1
fi

# Send email alert if any issues detected
if [ "$ALERT" = "1" ]; then
    cat $TEMP_FILE | mail -s "ALERT: System Health Issues on $(hostname)" $ALERT_EMAIL
fi

# Append to log file
cat $TEMP_FILE >> $LOG_FILE
rm $TEMP_FILE

# Keep log file size reasonable (last 1000 lines)
tail -1000 $LOG_FILE > ${LOG_FILE}.tmp && mv ${LOG_FILE}.tmp $LOG_FILE