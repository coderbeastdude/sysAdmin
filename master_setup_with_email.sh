#!/bin/bash

# Enhanced Master Server Setup Script
# Purpose: Orchestrate the execution of all setup scripts in the correct order
# Note: add_sudo_users.sh should be run BEFORE this script and manually verified

# Configuration
LOG_FILE="/var/log/server_setup.log"
SCRIPT_DIR=$(pwd)
EMAIL="admin@yourdomain.com"  # CHANGE THIS TO YOUR ACTUAL EMAIL

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}" >&2
    exit 1
fi

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "info")
            echo -e "${YELLOW}[INFO]${NC} $message"
            ;;
        "success")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Function to check if email address has been changed from default
check_email_configured() {
    if [ "$EMAIL" == "admin@yourdomain.com" ]; then
        print_status "error" "Email address not configured!"
        echo
        echo "Please edit this script and change the EMAIL variable to your actual email address."
        echo "Current value: $EMAIL"
        echo "Example: EMAIL=\"your-actual-email@domain.com\""
        echo
        read -p "Would you like to continue with the default email and change it later? (y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "info" "Please edit the script and run again."
            exit 1
        fi
        print_status "warning" "Continuing with default email. Remember to change it later!"
    else
        print_status "success" "Email configured as: $EMAIL"
    fi
}

# Start setup
echo "=========================================="
echo "Enhanced Master Server Setup Script"
echo "=========================================="
echo
echo "This script will:"
echo "1. Check prerequisites"
echo "2. Set up email system (msmtp)"
echo "3. Apply server hardening"
echo "4. Configure Nginx optimizations"
echo "5. Set up Redis security"
echo "6. Install monitoring scripts"
echo "7. Configure cron jobs"
echo "8. Set up log rotation"
echo
read -p "Do you want to continue? (y/N): " response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_status "info" "Setup cancelled."
    exit 0
fi

# Log start
echo "Enhanced master server setup started: $(date)" > $LOG_FILE
echo "Using email address: $EMAIL" >> $LOG_FILE

# Check email configuration
check_email_configured

# Function to run a script and log results
run_script() {
    local script=$1
    local description=$2
    
    echo
    print_status "info" "Running: $description"
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
            print_status "success" "$description completed"
        else
            echo "ERROR: $description failed with status $status" >> $LOG_FILE
            print_status "error" "$description failed. Check $LOG_FILE for details."
            
            # Ask if we should continue
            read -p "Continue with setup? (y/N): " continue_response
            if [[ ! "$continue_response" =~ ^[Yy]$ ]]; then
                print_status "info" "Setup stopped by user."
                exit 1
            fi
        fi
    else
        echo "ERROR: Script $script not found!" >> $LOG_FILE
        print_status "error" "Script $script not found!"
        
        if [ "$script" == "setup_msmtp.sh" ]; then
            print_status "warning" "msmtp setup skipped. You'll need to configure email manually later."
        else
            read -p "Continue with setup? (y/N): " continue_response
            if [[ ! "$continue_response" =~ ^[Yy]$ ]]; then
                print_status "info" "Setup stopped by user."
                exit 1
            fi
        fi
    fi
    
    echo "End time: $(date)" >> $LOG_FILE
    echo "---------------------------------------" >> $LOG_FILE
    
    # Small pause between scripts
    sleep 2
}

# Create scripts directory
print_status "info" "Creating /opt/admin/scripts directory..."
echo "Creating /opt/admin/scripts directory..." >> $LOG_FILE
mkdir -p /opt/admin/scripts

# 1. Set up email system
print_status "info" "Setting up email system with msmtp..."
run_script "setup_msmtp.sh" "Email System Setup (msmtp)"

# Check if msmtp was configured
if [ -f "/etc/msmtprc" ]; then
    print_status "info" "msmtp installed. You need to configure /etc/msmtprc with your email server details."
    
    # Automatically update msmtp config with the email if it's not the default
    if [ "$EMAIL" != "admin@yourdomain.com" ]; then
        print_status "info" "Updating msmtp configuration with your email address..."
        # Extract domain from email
        DOMAIN=$(echo "$EMAIL" | cut -d@ -f2)
        # Update from address
        sed -i "s/alerts@yourdomain.com/${EMAIL}/g" /etc/msmtprc
        sed -i "s/yourdomain.com/${DOMAIN}/g" /etc/msmtprc
    fi
    
    echo
    print_status "warning" "IMPORTANT: Before proceeding, configure your email server settings:"
    echo "1. Edit /etc/msmtprc"
    echo "2. Replace placeholder values with your actual email server details"
    echo "3. Test email: /opt/admin/scripts/test_email.sh your@email.com"
    echo
    read -p "Have you configured msmtp with your email server settings? (y/N): " email_configured
    if [[ ! "$email_configured" =~ ^[Yy]$ ]]; then
        print_status "warning" "Email not fully configured. Continuing anyway..."
        print_status "info" "Remember to configure /etc/msmtprc before expecting email alerts to work."
    fi
else
    print_status "warning" "msmtp setup failed or skipped. Email alerts may not work."
fi

# 2. Server Hardening
run_script "secure_hardening.sh" "Server Hardening"

# 3. Nginx Hardening
run_script "nginx_hardening.sh" "Nginx Hardening"

# 4. Redis Security
run_script "redis_security.sh" "Redis Security Configuration"

# 5. Update service watchdog script for Redis monitoring
run_script "redis_watchdog_update.sh" "Redis Service Watchdog Update"

# 6. Set up Go application monitoring
run_script "go_watchdog_update.sh" "Go Application Monitoring Setup"

# 7. Copy all scripts to admin directory
print_status "info" "Copying all scripts to /opt/admin/scripts..."
echo "Copying all scripts to /opt/admin/scripts..." >> $LOG_FILE
cp $SCRIPT_DIR/*.sh /opt/admin/scripts/
chmod +x /opt/admin/scripts/*.sh

# Update email addresses in all monitoring scripts
if [ "$EMAIL" != "admin@yourdomain.com" ]; then
    print_status "info" "Updating email address in all monitoring scripts..."
    find /opt/admin/scripts -name "*.sh" -type f -exec sed -i "s/admin@example.com/${EMAIL}/g" {} \;
    find /opt/admin/scripts -name "*.sh" -type f -exec sed -i "s/admin@yourdomain.com/${EMAIL}/g" {} \;
fi

# 8. Create cron jobs
print_status "info" "Setting up cron jobs for automated monitoring and maintenance..."
echo "Setting up cron jobs for automated monitoring and maintenance..." >> $LOG_FILE

cat > /etc/cron.d/server-management << EOF
# Server Management Cron Jobs
MAILTO=$EMAIL

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

# 9. Set up log rotation
print_status "info" "Setting up log rotation..."
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

# 10. Run first instance of each monitoring script
print_status "info" "Running initial monitoring checks..."
echo "Running initial monitoring checks..." >> $LOG_FILE
/opt/admin/scripts/system_health_check.sh 2>&1 | tee -a $LOG_FILE
/opt/admin/scripts/security_monitor.sh 2>&1 | tee -a $LOG_FILE
/opt/admin/scripts/master_monitor.sh 2>&1 | tee -a $LOG_FILE

# 11. Test email system
if [ -f "/opt/admin/scripts/test_email.sh" ]; then
    print_status "info" "Testing email system..."
    /opt/admin/scripts/test_email.sh $EMAIL
    
    if [ $? -eq 0 ]; then
        print_status "success" "Test email sent! Check your inbox."
    else
        print_status "warning" "Test email failed. Check /var/log/msmtp.log for details."
    fi
fi

# 12. Create a post-setup summary
cat > /root/server-setup-summary.txt << EOF
Server Setup Summary
====================
Date: $(date)
Email Address: $EMAIL
SSH Port: 2222

IMPORTANT NEXT STEPS:
--------------------
1. Configure email server settings in /etc/msmtprc if not already done
2. Test email functionality: /opt/admin/scripts/test_email.sh $EMAIL
3. Reconnect via SSH using port 2222: ssh -p 2222 username@server_ip
4. Review initial reports:
   - /var/log/system_status_report.txt
   - /var/log/security_monitor.log
   - /var/log/system_health_check.log

SERVICES STATUS:
----------------
$(systemctl status nginx postgresql redis-server || true)

LOG FILES:
----------
- Master setup log: $LOG_FILE
- Email configuration: /var/log/msmtp.log
- System health: /var/log/system_health_check.log
- Security monitor: /var/log/security_monitor.log

MONITORING SYSTEM:
------------------
All monitoring scripts are installed and scheduled to run automatically.
Check /etc/cron.d/server-management for the schedule.

BACKUP LOCATIONS:
-----------------
- PostgreSQL backups: /var/backups/postgresql/
- File backups: /var/backups/files/

Remember to:
1. Set strong passwords for all accounts
2. Keep the server updated (automated but review logs)
3. Monitor email alerts regularly
EOF

# Final summary
print_status "info" "Setup completed. Generating summary..."
echo >> $LOG_FILE
echo "Master server setup completed: $(date)" | tee -a $LOG_FILE
echo "=========================================" | tee -a $LOG_FILE

echo
echo "=========================================="
echo "MASTER SERVER SETUP COMPLETE"
echo "=========================================="
echo
echo "CONFIGURATION SUMMARY:"
echo "----------------------"
echo "Email Address: $EMAIL"
echo "SSH Port: 2222"
echo "Log File: $LOG_FILE"
echo "Summary: /root/server-setup-summary.txt"
echo
echo "CRITICAL NEXT STEPS:"
echo "--------------------"
echo "1. ${RED}IMPORTANT:${NC} SSH is now running on port 2222"
echo "   Reconnect using: ssh -p 2222 username@server_ip"
echo
echo "2. Email Configuration:"
echo "   - Edit /etc/msmtprc if not already configured"
echo "   - Test email: /opt/admin/scripts/test_email.sh $EMAIL"
echo
echo "3. Monitoring is active and will send alerts to: $EMAIL"
echo
echo "4. Check initial reports:"
echo "   - cat /var/log/system_status_report.txt"
echo "   - cat /var/log/security_monitor.log"
echo
echo "5. View complete setup log: cat $LOG_FILE"
echo
print_status "success" "Server setup completed successfully!"
echo
echo "Note: You will be disconnected. Reconnect using port 2222."
echo "=========================================="
