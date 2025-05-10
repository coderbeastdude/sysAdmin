#!/bin/bash

# Go Application Monitoring Script
# Purpose: Monitor Go application health, performance, and logs
# Recommended cron: */5 * * * * /opt/admin/scripts/go_app_monitor.sh

# Configuration
LOG_FILE="/var/log/go_app_monitor.log"
ALERT_EMAIL="admin@example.com"
GO_APP_NAME="myapp"  # Name of your Go application service
GO_APP_URL="http://localhost:8080"  # Base URL of your Go application
HEALTH_ENDPOINT="/health/details"  # Health check endpoint
MEMORY_THRESHOLD=90  # Alert if memory usage is above 90%
CPU_THRESHOLD=80  # Alert if CPU usage is above 80%
GO_APP_LOG="/var/log/go_app.log"  # Go application log file

# Log start
echo "Go application monitor check: $(date)" >> $LOG_FILE

# Check if Go application service is running
if ! systemctl is-active --quiet $GO_APP_NAME; then
    echo "ERROR: Go application service is not running!" >> $LOG_FILE
    echo "Go application service $GO_APP_NAME is not running on $(hostname)" | mail -s "Go Application Service Alert" $ALERT_EMAIL
    exit 1
fi

# Check health endpoint
echo "Checking Go application health endpoint..." >> $LOG_FILE
HEALTH_CHECK=$(curl -s -o /tmp/health_response.json -w "%{http_code}" $GO_APP_URL$HEALTH_ENDPOINT)

if [ "$HEALTH_CHECK" != "200" ]; then
    echo "WARNING: Go application health check failed with status $HEALTH_CHECK" >> $LOG_FILE
    echo "Go application health check failed on $(hostname) with status $HEALTH_CHECK" | mail -s "Go Application Health Alert" $ALERT_EMAIL
else
    echo "Go application health check: OK" >> $LOG_FILE
    
    # Parse health check response for component status
    HEALTH_STATUS=$(cat /tmp/health_response.json | jq -r '.status')
    echo "Overall health status: $HEALTH_STATUS" >> $LOG_FILE
    
    # Check for component warnings/failures
    if [ "$HEALTH_STATUS" != "UP" ]; then
        echo "WARNING: Go application reported health status: $HEALTH_STATUS" >> $LOG_FILE
        
        # Get details of failed components
        FAILED_COMPONENTS=$(cat /tmp/health_response.json | jq -r '.components | to_entries[] | select(.value.status != "UP") | .key + ": " + .value.status + " - " + .value.message')
        echo "Failed components:" >> $LOG_FILE
        echo "$FAILED_COMPONENTS" >> $LOG_FILE
        
        echo "Go application reported health issues on $(hostname): $HEALTH_STATUS" | mail -s "Go Application Component Alert" $ALERT_EMAIL
    fi
fi

# Check memory and CPU usage
GO_PID=$(ps aux | grep "$GO_APP_NAME" | grep -v grep | awk '{print $2}')

if [ -n "$GO_PID" ]; then
    # Get memory usage percentage
    MEM_USAGE=$(ps -p $GO_PID -o %mem | tail -1 | tr -d ' ')
    echo "Memory usage: ${MEM_USAGE}%" >> $LOG_FILE
    
    # Get CPU usage percentage
    CPU_USAGE=$(ps -p $GO_PID -o %cpu | tail -1 | tr -d ' ')
    echo "CPU usage: ${CPU_USAGE}%" >> $LOG_FILE
    
    # Alert if memory usage is too high
    if (( $(echo "$MEM_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
        echo "WARNING: High memory usage detected: ${MEM_USAGE}%" >> $LOG_FILE
        echo "Go application high memory usage (${MEM_USAGE}%) on $(hostname)" | mail -s "Go Application Resource Alert" $ALERT_EMAIL
    fi
    
    # Alert if CPU usage is too high
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        echo "WARNING: High CPU usage detected: ${CPU_USAGE}%" >> $LOG_FILE
        echo "Go application high CPU usage (${CPU_USAGE}%) on $(hostname)" | mail -s "Go Application Resource Alert" $ALERT_EMAIL
    fi
else
    echo "WARNING: Could not find Go application process" >> $LOG_FILE
fi

# Check log file for errors
if [ -f "$GO_APP_LOG" ]; then
    echo "Analyzing Go application logs..." >> $LOG_FILE
    
    # Get recent error logs
    ERROR_COUNT=$(grep -i "error\|panic\|fatal" $GO_APP_LOG | wc -l)
    RECENT_ERRORS=$(grep -i "error\|panic\|fatal" $GO_APP_LOG | tail -10)
    
    echo "Found $ERROR_COUNT error entries in log" >> $LOG_FILE
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "Recent errors:" >> $LOG_FILE
        echo "$RECENT_ERRORS" >> $LOG_FILE
        
        # If there are many new errors, send an alert
        NEW_ERRORS=$(grep -i "error\|panic\|fatal" $GO_APP_LOG | grep "$(date +"%Y-%m-%d")" | wc -l)
        if [ $NEW_ERRORS -gt 10 ]; then
            echo "WARNING: $NEW_ERRORS new errors today in Go application log" >> $LOG_FILE
            echo "$NEW_ERRORS new errors in Go application log on $(hostname)" | mail -s "Go Application Error Alert" $ALERT_EMAIL
        fi
    fi
fi

# Measure response time of key endpoints
ENDPOINTS=("/api/products" "/api/users" "/api/orders")

echo "Checking endpoint response times..." >> $LOG_FILE
for endpoint in "${ENDPOINTS[@]}"; do
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" $GO_APP_URL$endpoint)
    echo "Endpoint $endpoint response time: ${RESPONSE_TIME}s" >> $LOG_FILE
    
    # Alert if response time is too high (> 2 seconds)
    if (( $(echo "$RESPONSE_TIME > 2.0" | bc -l) )); then
        echo "WARNING: Slow response time for $endpoint: ${RESPONSE_TIME}s" >> $LOG_FILE
        echo "Slow response time (${RESPONSE_TIME}s) for $endpoint on $(hostname)" | mail -s "Go Application Performance Alert" $ALERT_EMAIL
    fi
done

# Log completion
echo "Go application monitoring completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
