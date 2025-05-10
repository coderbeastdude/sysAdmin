#!/bin/bash

# Master Monitoring Script
# Purpose: Centralized script to run all monitoring scripts and report status
# Recommended cron: 0 * * * * /path/to/master_monitor.sh

# Configuration
LOG_DIR="/var/log"
SCRIPTS_DIR="/opt/admin/scripts"
REPORT_FILE="/var/log/system_status_report.txt"
ALERT_EMAIL="admin@example.com"
HOSTNAME=$(hostname)

# List of scripts to run with their descriptions
declare -A SCRIPTS
SCRIPTS["system_health_check.sh"]="System Health Check"
SCRIPTS["disk_space_monitor.sh"]="Disk Space Monitor"
SCRIPTS["security_monitor.sh"]="Security Monitor"
SCRIPTS["service_watchdog.sh"]="Service Watchdog"
SCRIPTS["network_monitor.sh"]="Network Monitor"

# Create report header
echo "System Status Report for $HOSTNAME" > $REPORT_FILE
echo "Generated: $(date)" >> $REPORT_FILE
echo "=======================================" >> $REPORT_FILE

# System overview
echo -e "\nSystem Overview:" >> $REPORT_FILE
uptime >> $REPORT_FILE
echo -e "\nMemory Usage:" >> $REPORT_FILE
free -h >> $REPORT_FILE
echo -e "\nDisk Usage:" >> $REPORT_FILE
df -h / /var /home >> $REPORT_FILE

# Run each monitoring script and collect status
echo -e "\nMonitoring Script Status:" >> $REPORT_FILE
echo "=======================================" >> $REPORT_FILE

for script in "${!SCRIPTS[@]}"; do
    description=${SCRIPTS[$script]}
    echo -e "\nRunning: $description" >> $REPORT_FILE
    
    if [ -x "$SCRIPTS_DIR/$script" ]; then
        # Run the script and capture output
        output=$($SCRIPTS_DIR/$script 2>&1)
        status=$?
        
        if [ $status -eq 0 ]; then
            echo "Status: OK" >> $REPORT_FILE
        else
            echo "Status: FAILED (Exit code: $status)" >> $REPORT_FILE
            echo "Error output:" >> $REPORT_FILE
            echo "$output" >> $REPORT_FILE
        fi
    else
        echo "Status: SCRIPT NOT FOUND OR NOT EXECUTABLE" >> $REPORT_FILE
    fi
done

# Check for recent errors in logs
echo -e "\nRecent System Errors:" >> $REPORT_FILE
echo "=======================================" >> $REPORT_FILE
grep -i "error\|fail\|critical" /var/log/syslog | tail -10 >> $REPORT_FILE

# Check service status
echo -e "\nService Status:" >> $REPORT_FILE
echo "=======================================" >> $REPORT_FILE
services=("postgresql" "nginx" "express-app")
for service in "${services[@]}"; do
    status=$(systemctl is-active $service)
    echo "$service: $status" >> $REPORT_FILE
done

# Check for failed systemd services
echo -e "\nFailed Systemd Services:" >> $REPORT_FILE
systemctl --failed >> $REPORT_FILE

# Check for pending system updates
echo -e "\nPending System Updates:" >> $REPORT_FILE
apt-get -s upgrade | grep -i "upgraded\|newly installed" >> $REPORT_FILE

# Send the report via email
cat $REPORT_FILE | mail -s "System Status Report for $HOSTNAME" $ALERT_EMAIL

echo "Master monitoring completed at $(date)" >> $LOG_DIR/master_monitor.log
