#!/bin/bash

# Master Server Setup Script
# Purpose: Orchestrate the execution of all setup scripts in the correct order
# Note: add_sudo_users.sh should be run BEFORE this script and manually verified

# Configuration
LOG_FILE="/var/log/server_setup.log"
SCRIPT_DIR=$(pwd)
EMAIL="admin@example.com"  # Replace with your email

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Log start
echo "Master server setup started: $(date)" > $LOG_FILE
echo "Running from directory: $SCRIPT_DIR" >> $LOG_FILE

# Function to run a script and log results
run_script() {
    local script=$1
    local description=$2
    
    echo "---------------------------------------" >> $LOG_FILE
    echo "Running: $description ($script)" >> $LOG_FILE
    echo "Start time: $(date)" >> $LOG_FILE
    
    if [ -f "$SCRIPT_DIR/$script" ]; then
        # Make script executable
        chmod +x "$SCRIPT_DIR/$script"
        
        # Run the script
        "$SCRIPT_DIR/$script" >> $LOG_FILE 2>&1
        status=$?
        
        if [ $status -eq 0 ]; then
            echo "SUCCESS: $description completed successfully." >> $LOG_FILE
            echo "SUCCESS: $description"
        else
            echo "ERROR: $description failed with status $status" >> $LOG_FILE
            echo "ERROR: $description failed. Check $LOG_FILE for details."
        fi
    else
        echo "ERROR: Script $script not found!" >> $LOG_FILE
        echo "ERROR: Script $script not found!"
    fi
    
    echo "End time: $(date)" >> $LOG_FILE
    echo "---------------------------------------" >> $LOG_FILE
    
    # Small pause between scripts
    sleep 2
}

# Create scripts directory
echo "Creating /opt/admin/scripts directory..." >> $LOG_FILE
mkdir -p /opt/admin/scripts

# 1. Server Hardening
run_script "secure_hardening.sh" "Server Hardening"

# 2. Nginx Hardening
run_script "nginx_hardening.sh" "Nginx Hardening"

# 3. Redis Security
run_script "redis_security.sh" "Redis Security Configuration"

# 4. Update service watchdog script for Redis monitoring
run_script "redis_watchdog_update.sh" "Redis Service Watchdog Update"

# 5. Set up Go application monitoring
run_script "go_watchdog_update.sh" "Go Application Monitoring Setup"

# 6. Set up all monitoring scripts
echo "Copying all scripts to /opt/admin/scripts..." >> $LOG_FILE
cp $SCRIPT_DIR/*.sh /opt/admin/scripts/
chmod +x /opt/admin/scripts/*.sh

# 7. Create cron jobs
echo "Setting up cron jobs for automated monitoring and maintenance..." >> $LOG_FILE

cat > /etc/cron.d/server-management << 'EOF'
# System Health Check - Every 15 minutes
*/15 * * * * root /opt/admin/scripts/system_health_check.sh

# Disk Space Monitor - Every 4 hours
0 */4 * * * root /opt/admin/scripts/disk_space_monitor.sh

# Log Analyzer - Daily at 1 AM
0 1 * * * root /opt/admin/scripts/log_analyzer.sh

# Security Monitor - Every 30 minutes
*/30 * * * * root /opt/admin/scripts/security_monitor.sh

# PostgreSQL Backup - Daily at 2 AM
0 2 * * * root /opt/admin/scripts/postgres_backup.sh

# File Backup - Daily at 3 AM
0 3 * * * root /opt/admin/scripts/file_backup.sh

# System Update - Weekly on Sunday at 4 AM
0 4 * * 0 root /opt/admin/scripts/system_update.sh

# Network Monitor - Every 10 minutes
*/10 * * * * root /opt/admin/scripts/network_monitor.sh

# Service Watchdog - Every 5 minutes
*/5 * * * * root /opt/admin/scripts/service_watchdog.sh

# PostgreSQL Optimizer - Weekly on Sunday at 2 AM
0 2 * * 0 root /opt/admin/scripts/postgres_optimizer.sh

# Cache Cleaner - Daily at 3 AM
0 3 * * * root /opt/admin/scripts/cache_cleaner.sh

# SSL Certificate Monitor - Daily at midnight
0 0 * * * root /opt/admin/scripts/ssl_cert_monitor.sh

# Master Monitor - Hourly
0 * * * * root /opt/admin/scripts/master_monitor.sh

# Redis Monitor - Every 10 minutes
*/10 * * * * root /opt/admin/scripts/redis_monitor.sh

# Go Application Monitor - Every 5 minutes
*/5 * * * * root /opt/admin/scripts/go_app_monitor.sh

# E-commerce Checkout Monitor - Every 10 minutes
*/10 * * * * root /opt/admin/scripts/checkout_monitor.sh

# NPM Security Scanner - Daily at 3 AM
0 3 * * * root /opt/admin/scripts/npm_security_scanner.sh

# Frontend Build Integrity - Daily at 1 AM
0 1 * * * root /opt/admin/scripts/frontend_build_integrity.sh

# PCI Compliance Check - Daily at 1 AM
0 1 * * * root /opt/admin/scripts/pci_compliance_check.sh
EOF

chmod 644 /etc/cron.d/server-management

# 8. Set up log rotation
echo "Setting up log rotation..." >> $LOG_FILE

cat > /etc/logrotate.d/admin-scripts << 'EOF'
/var/log/*_monitor.log /var/log/service_watchdog.log /var/log/postgres_*.log /var/log/system_*.log /var/log/nginx_*.log /var/log/checkout_*.log /var/log/frontend_*.log /var/log/pci_*.log /var/log/redis_*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 root adm
}
EOF

# 9. Run first instance of each monitoring script
echo "Running initial monitoring checks..." >> $LOG_FILE
/opt/admin/scripts/system_health_check.sh
/opt/admin/scripts/security_monitor.sh
/opt/admin/scripts/master_monitor.sh

# Log completion
echo "Master server setup completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE

echo "Server setup completed!"
echo "Log file: $LOG_FILE"
echo ""
echo "IMPORTANT: Server has been hardened. SSH now runs on port 2222."
echo "Reconnect using: ssh -p 2222 username@server_ip"
echo ""
echo "All monitoring scripts have been installed and scheduled."
echo "Check /var/log/master_monitor.log for system status reports."
