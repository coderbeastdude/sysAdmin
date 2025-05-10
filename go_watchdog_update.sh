#!/bin/bash

# Update service_watchdog.sh to include Go application monitoring
# This script modifies the existing service_watchdog.sh to add Go-specific checks

# Path to the service watchdog script
WATCHDOG_SCRIPT="/opt/admin/scripts/service_watchdog.sh"

# Make a backup of the original script
cp $WATCHDOG_SCRIPT ${WATCHDOG_SCRIPT}.bak

# Add Go app to the SERVICES variable (assuming your Go app service is named "go-app")
sed -i 's/SERVICES="postgresql nginx express-app"/SERVICES="postgresql nginx express-app go-app"/' $WATCHDOG_SCRIPT

# Add Go-specific health check section at the end of the script
# Find the line before the script closing line
LINE_NUM=$(grep -n "# Log completion" $WATCHDOG_SCRIPT | cut -d: -f1)

# Insert Go health check before the log completion section
sed -i "${LINE_NUM}i\\
# Go application health check\\
if systemctl is-active --quiet go-app; then\\
    echo \"Checking Go application health endpoint...\" >> \$LOG_FILE\\
    GO_APP_URL=\"http://localhost:8080\"  # Adjust to your Go app's URL\\
    HEALTH_ENDPOINT=\"/health\"  # Basic health endpoint\\
    \\
    # Try to connect to health endpoint\\
    health_check=\$(curl -s -o /dev/null -w \"%{http_code}\" \$GO_APP_URL\$HEALTH_ENDPOINT)\\
    \\
    if [ \"\$health_check\" != \"200\" ]; then\\
        echo \"WARNING: Go application health check failed with status \$health_check\" >> \$LOG_FILE\\
        \\
        # Check if we should restart\\
        service=\"go-app\"\\
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
            echo \"Attempting to restart Go application...\" >> \$LOG_FILE\\
            systemctl restart go-app\\
            \\
            # Increment restart count\\
            new_count=\$((current_count + 1))\\
            sed -i \"s/^\$service:\$current_count:\$last_date/\$service:\$new_count:\$today/\" \$RESTART_COUNT_FILE\\
            \\
            # Send notification\\
            echo \"Go application was down and has been restarted on \$(hostname)\" | mail -s \"Service Restart Notification\" \$ALERT_EMAIL\\
        else\\
            echo \"ERROR: Go application has been restarted \$current_count times today, exceeding limit of \$MAX_RESTARTS\" >> \$LOG_FILE\\
            echo \"Go application has failed \$current_count times today on \$(hostname)\" | mail -s \"Critical Service Failure Alert\" \$ALERT_EMAIL\\
        fi\\
    fi\\
fi\\
" $WATCHDOG_SCRIPT

echo "Service watchdog script updated to monitor Go application"
echo "Original script backed up at ${WATCHDOG_SCRIPT}.bak"
