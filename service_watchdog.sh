#!/bin/bash

# Service Watchdog Script
# Purpose: Monitor and restart critical services if they fail
# Recommended cron: */5 * * * * /path/to/service_watchdog.sh

# Configuration
LOG_FILE="/var/log/service_watchdog.log"
ALERT_EMAIL="admin@example.com"
SERVICES="postgresql nginx express-app"  # Adjust service names as needed
MAX_RESTARTS=3  # Maximum number of restarts per day
RESTART_COUNT_FILE="/tmp/service_restarts.txt"

# Initialize restart count file if it doesn't exist
if [ ! -f "$RESTART_COUNT_FILE" ]; then
    for service in $SERVICES; do
        echo "$service:0:$(date +%Y%m%d)" > $RESTART_COUNT_FILE
    done
fi

# Log start
echo "Service watchdog started: $(date)" >> $LOG_FILE

# Check and restart services if needed
for service in $SERVICES; do
    echo "Checking $service..." >> $LOG_FILE
    
    # Check if service is active
    if ! systemctl is-active --quiet $service; then
        echo "WARNING: $service is not running!" >> $LOG_FILE
        
        # Get current restart count
        current_line=$(grep "^$service:" $RESTART_COUNT_FILE)
        current_count=$(echo $current_line | cut -d: -f2)
        last_date=$(echo $current_line | cut -d: -f3)
        today=$(date +%Y%m%d)
        
        # Reset count if it's a new day
        if [ "$last_date" != "$today" ]; then
            current_count=0
            last_date=$today
        fi
        
        # Check if we've exceeded max restarts
        if [ $current_count -lt $MAX_RESTARTS ]; then
            echo "Attempting to restart $service..." >> $LOG_FILE
            systemctl restart $service
            
            # Check if restart was successful
            if systemctl is-active --quiet $service; then
                echo "$service restarted successfully." >> $LOG_FILE
                
                # Increment restart count
                new_count=$((current_count + 1))
                sed -i "s/^$service:$current_count:$last_date/$service:$new_count:$today/" $RESTART_COUNT_FILE
                
                # Send notification
                echo "$service was down and has been restarted on $(hostname)" | mail -s "Service Restart Notification" $ALERT_EMAIL
            else
                echo "ERROR: Failed to restart $service!" >> $LOG_FILE
                echo "$service failed to restart on $(hostname)" | mail -s "Service Failure Alert" $ALERT_EMAIL
            fi
        else
            echo "ERROR: $service has been restarted $current_count times today, exceeding limit of $MAX_RESTARTS" >> $LOG_FILE
            echo "$service has failed $current_count times today on $(hostname)" | mail -s "Critical Service Failure Alert" $ALERT_EMAIL
        fi
    else
        echo "$service is running properly." >> $LOG_FILE
    fi
done

# Check Express application health endpoint (if available)
if [ -n "$(netstat -tuln | grep -E ':(8080)')" ]; then
    echo "Checking Express application health endpoint..." >> $LOG_FILE
    
    # Try to connect to health endpoint (adjust URL as needed)
    health_check=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
    
    if [ "$health_check" != "200" ]; then
        echo "WARNING: Express application health check failed with status $health_check" >> $LOG_FILE
        
        # Check if we should restart
        service="express-app"
        current_line=$(grep "^$service:" $RESTART_COUNT_FILE)
        current_count=$(echo $current_line | cut -d: -f2)
        last_date=$(echo $current_line | cut -d: -f3)
        today=$(date +%Y%m%d)
        
        # Reset count if it's a new day
        if [ "$last_date" != "$today" ]; then
            current_count=0
            last_date=$today
        fi
        
        # Check if we've exceeded max restarts
        if [ $current_count -lt $MAX_RESTARTS ]; then
            echo "Attempting to restart Express application..." >> $LOG_FILE
            systemctl restart express-app
            
            # Increment restart count
            new_count=$((current_count + 1))
            sed -i "s/^$service:$current_count:$last_date/$service:$new_count:$today/" $RESTART_COUNT_FILE
            
            # Send notification
            echo "$service was down and has been restarted on $(hostname)" | mail -s "Service Restart Notification" $ALERT_EMAIL
        else
            echo "ERROR: $service has been restarted $current_count times today, exceeding limit of $MAX_RESTARTS" >> $LOG_FILE
            echo "$service has failed $current_count times today on $(hostname)" | mail -s "Critical Service Failure Alert" $ALERT_EMAIL
        fi
    fi
fi

# Log completion
echo "Service watchdog completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
