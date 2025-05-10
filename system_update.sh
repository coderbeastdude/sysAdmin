#!/bin/bash

# System Update Script
# Purpose: Safely update system packages and dependencies
# Recommended cron: 0 4 * * 0 /path/to/system_update.sh

# Configuration
LOG_FILE="/var/log/system_update.log"
ALERT_EMAIL="admin@example.com"
REBOOT_REQUIRED_FILE="/var/run/reboot-required"

# Log start
echo "System update started: $(date)" >> $LOG_FILE

# Function to check if services are running
check_services() {
    services=("postgresql" "nginx" "express-app")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service; then
            echo "WARNING: $service is not running!" >> $LOG_FILE
            return 1
        fi
    done
    return 0
}

# Check services before update
echo "Checking services before update..." >> $LOG_FILE
check_services
SERVICES_BEFORE=$?

# Update package lists
echo "Updating package lists..." >> $LOG_FILE
apt-get update >> $LOG_FILE 2>&1

# Check for security updates only
echo "Checking for security updates..." >> $LOG_FILE
SECURITY_UPDATES=$(apt-get -s upgrade | grep -i security | wc -l)
echo "Found $SECURITY_UPDATES security updates" >> $LOG_FILE

# Perform the upgrade
echo "Performing upgrade..." >> $LOG_FILE
apt-get -y upgrade >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Upgrade failed!" >> $LOG_FILE
    echo "System upgrade failed on $(hostname)" | mail -s "Update Failure Alert" $ALERT_EMAIL
    exit 1
fi

# Clean up
echo "Cleaning up..." >> $LOG_FILE
apt-get -y autoremove >> $LOG_FILE 2>&1
apt-get -y autoclean >> $LOG_FILE 2>&1

# Check services after update
echo "Checking services after update..." >> $LOG_FILE
check_services
SERVICES_AFTER=$?

# If services were running before but not after, try to restart them
if [ $SERVICES_BEFORE -eq 0 ] && [ $SERVICES_AFTER -ne 0 ]; then
    echo "Some services stopped after update. Attempting to restart..." >> $LOG_FILE
    
    services=("postgresql" "nginx" "express-app")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service; then
            echo "Restarting $service..." >> $LOG_FILE
            systemctl restart $service >> $LOG_FILE 2>&1
        fi
    done
    
    # Check services again
    check_services
    if [ $? -ne 0 ]; then
        echo "ERROR: Some services failed to restart after update!" >> $LOG_FILE
        echo "Services failed after system update on $(hostname)" | mail -s "Update Service Failure Alert" $ALERT_EMAIL
    fi
fi

# Check if reboot is required
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
    echo "System requires a reboot after updates." >> $LOG_FILE
    echo "System update completed on $(hostname) but requires a reboot." | mail -s "System Update Reboot Required" $ALERT_EMAIL
else
    echo "No reboot required." >> $LOG_FILE
fi

# Update Node.js dependencies if needed (for Express app)
if [ -d "/var/www/express-app" ]; then
    echo "Updating Node.js dependencies..." >> $LOG_FILE
    cd /var/www/express-app
    npm outdated >> $LOG_FILE 2>&1
    # Uncomment to automatically update (use with caution)
    # npm update >> $LOG_FILE 2>&1
fi

# Log completion
echo "System update completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
