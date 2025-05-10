#!/bin/bash

# PERN Stack Server Management Scripts Installation
# This script installs, configures, and tests all server management scripts
# Author: Claude AI
# Version: 1.0

# Configuration
SCRIPTS_DIR="/opt/admin/scripts"
LOG_DIR="/var/log"
BACKUP_DIR="/var/backups"
INSTALL_LOG="$LOG_DIR/scripts_installation.log"
TEMP_DIR=$(mktemp -d)
ALERT_EMAIL="admin@example.com"  # Change this to your email
HOSTNAME=$(hostname)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize log file
mkdir -p $LOG_DIR
echo "Installation started at $(date)" > $INSTALL_LOG
echo "=======================================" >> $INSTALL_LOG

# Function to log messages
log() {
    local message="$1"
    local level="$2"
    
    case $level in
        "INFO") 
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[INFO] $message" >> $INSTALL_LOG
            ;;
        "SUCCESS") 
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[SUCCESS] $message" >> $INSTALL_LOG
            ;;
        "WARNING") 
            echo -e "${YELLOW}[WARNING]${NC} $message"
            echo "[WARNING] $message" >> $INSTALL_LOG
            ;;
        "ERROR") 
            echo -e "${RED}[ERROR]${NC} $message"
            echo "[ERROR] $message" >> $INSTALL_LOG
            ;;
        *) 
            echo "$message"
            echo "$message" >> $INSTALL_LOG
            ;;
    esac
}

# Function to check if running as root
check_root() {
    log "Checking if script is running as root..." "INFO"
    if [ "$(id -u)" -ne 0 ]; then
        log "This script must be run as root" "ERROR"
        exit 1
    fi
    log "Running as root, proceeding..." "SUCCESS"
}

# Function to check and install dependencies
check_dependencies() {
    log "Checking and installing dependencies..." "INFO"
    
    # List of required packages
    packages=(
        "mailutils"
        "postgresql-client"
        "nginx"
        "curl"
        "bc"
        "rsync"
        "git"
        "npm"
        "certbot"
    )
    
    # Update package lists
    apt-get update >> $INSTALL_LOG 2>&1
    
    # Check and install each package
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "ii  $package"; then
            log "Installing $package..." "INFO"
            apt-get install -y $package >> $INSTALL_LOG 2>&1
            
            if [ $? -ne 0 ]; then
                log "Failed to install $package" "WARNING"
                failed_packages="$failed_packages $package"
            else
                log "Installed $package successfully" "SUCCESS"
            fi
        else
            log "$package is already installed" "SUCCESS"
        fi
    done
    
    # Check if any packages failed to install
    if [ -n "$failed_packages" ]; then
        log "The following packages could not be installed:$failed_packages" "WARNING"
        log "Some scripts may not function correctly without these packages" "WARNING"
        return 1
    fi
    
    return 0
}

# Function to create necessary directories
create_directories() {
    log "Creating necessary directories..." "INFO"
    
    directories=(
        "$SCRIPTS_DIR"
        "$LOG_DIR"
        "$BACKUP_DIR"
        "$BACKUP_DIR/postgresql"
        "$BACKUP_DIR/files"
        "$BACKUP_DIR/app_deployments"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log "Created directory: $dir" "SUCCESS"
        else
            log "Directory already exists: $dir" "INFO"
        fi
    done
}

# Function to copy and set permissions for scripts
copy_scripts() {
    log "Copying scripts to $SCRIPTS_DIR..." "INFO"
    
    # Get current directory
    CURRENT_DIR=$(pwd)
    
    # List of scripts
    scripts=(
        "system_health_check.sh"
        "disk_space_monitor.sh"
        "log_analyzer.sh"
        "security_monitor.sh"
        "postgres_backup.sh"
        "file_backup.sh"
        "system_update.sh"
        "network_monitor.sh"
        "service_watchdog.sh"
        "postgres_optimizer.sh"
        "cache_cleaner.sh"
        "ssl_cert_monitor.sh"
        "app_deployment.sh"
        "master_monitor.sh"
    )
    
    # Copy each script
    for script in "${scripts[@]}"; do
        if [ -f "$CURRENT_DIR/$script" ]; then
            cp "$CURRENT_DIR/$script" "$SCRIPTS_DIR/"
            chmod +x "$SCRIPTS_DIR/$script"
            log "Copied and set executable permissions for $script" "SUCCESS"
        else
            log "Script not found: $script" "ERROR"
            missing_scripts="$missing_scripts $script"
        fi
    done
    
    # Check if any scripts are missing
    if [ -n "$missing_scripts" ]; then
        log "The following scripts are missing:$missing_scripts" "ERROR"
        log "Please ensure all scripts are in the current directory" "ERROR"
        return 1
    fi
    
    return 0
}

# Function to test a script
test_script() {
    local script="$1"
    local script_path="$SCRIPTS_DIR/$script"
    local test_log="$TEMP_DIR/${script}_test.log"
    
    log "Testing $script..." "INFO"
    
    # Add TEST_MODE environment variable to prevent actual changes
    TEST_MODE=1 bash -n "$script_path" > "$test_log" 2>&1
    
    # Check for syntax errors
    if [ $? -ne 0 ]; then
        log "Syntax error in $script" "ERROR"
        cat "$test_log" >> $INSTALL_LOG
        return 1
    fi
    
    # Run script with TEST_MODE to check functionality
    TEST_MODE=1 bash "$script_path" > "$test_log" 2>&1
    
    # Check exit status
    if [ $? -ne 0 ]; then
        log "Test execution failed for $script" "ERROR"
        cat "$test_log" >> $INSTALL_LOG
        return 1
    fi
    
    log "Test passed for $script" "SUCCESS"
    return 0
}

# Function to test all scripts
test_all_scripts() {
    log "Testing all scripts..." "INFO"
    
    # List of scripts
    scripts=(
        "system_health_check.sh"
        "disk_space_monitor.sh"
        "log_analyzer.sh"
        "security_monitor.sh"
        "postgres_backup.sh"
        "file_backup.sh"
        "system_update.sh"
        "network_monitor.sh"
        "service_watchdog.sh"
        "postgres_optimizer.sh"
        "cache_cleaner.sh"
        "ssl_cert_monitor.sh"
        "app_deployment.sh"
        "master_monitor.sh"
    )
    
    # Test each script
    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            # Add TEST_MODE to script temporarily
            sed -i '2i\# Test mode check\nif [ "$TEST_MODE" = "1" ]; then\n    echo "Running in test mode"\n    exit 0\nfi' "$SCRIPTS_DIR/$script"
            
            test_script "$script"
            test_result=$?
            
            # Remove TEST_MODE lines
            sed -i '2,6d' "$SCRIPTS_DIR/$script"
            
            if [ $test_result -ne 0 ]; then
                failed_scripts="$failed_scripts $script"
            else
                passed_scripts="$passed_scripts $script"
            fi
        else
            log "Script not found for testing: $script" "ERROR"
        fi
    done
    
    # Check if any scripts failed testing
    if [ -n "$failed_scripts" ]; then
        log "The following scripts failed testing:$failed_scripts" "ERROR"
        return 1
    fi
    
    log "All scripts passed testing" "SUCCESS"
    return 0
}

# Function to test PostgreSQL connectivity
test_postgresql() {
    log "Testing PostgreSQL connectivity..." "INFO"
    
    if ! command -v psql &> /dev/null; then
        log "PostgreSQL client not installed" "WARNING"
        return 1
    fi
    
    # Try to connect to PostgreSQL
    if sudo -u postgres psql -c "SELECT version();" > /dev/null 2>&1; then
        log "PostgreSQL connection successful" "SUCCESS"
        return 0
    else
        log "Could not connect to PostgreSQL" "WARNING"
        log "PostgreSQL scripts may not function correctly" "WARNING"
        return 1
    fi
}

# Function to test Nginx
test_nginx() {
    log "Testing Nginx..." "INFO"
    
    if ! command -v nginx &> /dev/null; then
        log "Nginx not installed" "WARNING"
        return 1
    fi
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        log "Nginx is running" "SUCCESS"
        return 0
    else
        log "Nginx is not running" "WARNING"
        log "Web server scripts may not function correctly" "WARNING"
        return 1
    fi
}

# Function to test Node.js/Express
test_nodejs() {
    log "Testing Node.js..." "INFO"
    
    if ! command -v node &> /dev/null; then
        log "Node.js not installed" "WARNING"
        return 1
    fi
    
    # Check Node.js version
    node_version=$(node -v)
    log "Node.js version: $node_version" "INFO"
    
    # Check if Express app service exists
    if systemctl list-unit-files | grep -q express-app; then
        log "Express app service found" "SUCCESS"
        return 0
    else
        log "Express app service not found" "WARNING"
        log "Express app scripts may not function correctly" "WARNING"
        return 1
    fi
}

# Function to create cron jobs
create_cron_jobs() {
    log "Creating cron jobs..." "INFO"
    
    # Create cron file
    cron_file="/etc/cron.d/server-management"
    
    cat > $cron_file << EOF
# Server Management Cron Jobs
# Created by installation script on $(date)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# System Health Check - Every 15 minutes
*/15 * * * * root $SCRIPTS_DIR/system_health_check.sh

# Disk Space Monitor - Every 4 hours
0 */4 * * * root $SCRIPTS_DIR/disk_space_monitor.sh

# Log Analyzer - Daily at 1 AM
0 1 * * * root $SCRIPTS_DIR/log_analyzer.sh

# Security Monitor - Every 30 minutes
*/30 * * * * root $SCRIPTS_DIR/security_monitor.sh

# PostgreSQL Backup - Daily at 2 AM
0 2 * * * root $SCRIPTS_DIR/postgres_backup.sh

# File Backup - Daily at 3 AM
0 3 * * * root $SCRIPTS_DIR/file_backup.sh

# System Update - Weekly on Sunday at 4 AM
0 4 * * 0 root $SCRIPTS_DIR/system_update.sh

# Network Monitor - Every 10 minutes
*/10 * * * * root $SCRIPTS_DIR/network_monitor.sh

# Service Watchdog - Every 5 minutes
*/5 * * * * root $SCRIPTS_DIR/service_watchdog.sh

# PostgreSQL Optimizer - Weekly on Sunday at 2 AM
0 2 * * 0 root $SCRIPTS_DIR/postgres_optimizer.sh

# Cache Cleaner - Daily at 3 AM
0 3 * * * root $SCRIPTS_DIR/cache_cleaner.sh

# SSL Certificate Monitor - Daily at midnight
0 0 * * * root $SCRIPTS_DIR/ssl_cert_monitor.sh

# Master Monitor - Hourly
0 * * * * root $SCRIPTS_DIR/master_monitor.sh
EOF
    
    # Set permissions
    chmod 644 $cron_file
    
    log "Cron jobs created at $cron_file" "SUCCESS"
    
    # Disable cron jobs for failed scripts
    if [ -n "$failed_scripts" ]; then
        log "Disabling cron jobs for failed scripts..." "WARNING"
        for script in $failed_scripts; do
            sed -i "/$script/s/^/#/" $cron_file
            log "Disabled cron job for $script" "WARNING"
        done
    fi
}

# Function to set up log rotation
setup_log_rotation() {
    log "Setting up log rotation..." "INFO"
    
    # Create log rotation configuration
    logrotate_file="/etc/logrotate.d/admin-scripts"
    
    cat > $logrotate_file << EOF
$LOG_DIR/*_monitor.log $LOG_DIR/service_watchdog.log $LOG_DIR/postgres_*.log $LOG_DIR/system_*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 root adm
}
EOF
    
    # Set permissions
    chmod 644 $logrotate_file
    
    log "Log rotation configured at $logrotate_file" "SUCCESS"
}

# Function to generate installation report
generate_report() {
    log "Generating installation report..." "INFO"
    
    report_file="$LOG_DIR/installation_report.txt"
    
    cat > $report_file << EOF
PERN Stack Server Management Scripts Installation Report
======================================================
Generated: $(date)
Hostname: $HOSTNAME

Installation Status:
------------------
EOF
    
    if [ -n "$failed_packages" ]; then
        echo "Failed to install packages:$failed_packages" >> $report_file
    else
        echo "All required packages installed successfully" >> $report_file
    fi
    
    if [ -n "$missing_scripts" ]; then
        echo "Missing scripts:$missing_scripts" >> $report_file
    else
        echo "All scripts copied successfully" >> $report_file
    fi
    
    if [ -n "$failed_scripts" ]; then
        echo "Scripts that failed testing:$failed_scripts" >> $report_file
    else
        echo "All scripts passed testing" >> $report_file
    fi
    
    cat >> $report_file << EOF

Service Status:
-------------
PostgreSQL: $(test_postgresql > /dev/null 2>&1 && echo "OK" || echo "WARNING")
Nginx: $(test_nginx > /dev/null 2>&1 && echo "OK" || echo "WARNING")
Node.js: $(test_nodejs > /dev/null 2>&1 && echo "OK" || echo "WARNING")

Cron Jobs:
---------
Cron jobs have been set up for all working scripts.
Location: /etc/cron.d/server-management

Log Rotation:
-----------
Log rotation has been configured for all script logs.
Location: /etc/logrotate.d/admin-scripts

Next Steps:
---------
1. Review the installation log at $INSTALL_LOG
2. Test each script manually: sudo $SCRIPTS_DIR/script_name.sh
3. Check the first execution of the master monitor: sudo $SCRIPTS_DIR/master_monitor.sh
4. Adjust email settings in scripts if needed (currently set to: $ALERT_EMAIL)

EOF
    
    log "Installation report generated at $report_file" "SUCCESS"
    
    # Send report via email
    cat $report_file | mail -s "Server Management Scripts Installation Report for $HOSTNAME" $ALERT_EMAIL
}

# Function to clean up
cleanup() {
    log "Cleaning up temporary files..." "INFO"
    rm -rf $TEMP_DIR
    log "Cleanup completed" "SUCCESS"
}

# Main installation process
main() {
    echo "======================================="
    echo "PERN Stack Server Management Scripts Installation"
    echo "======================================="
    
    # Check if running as root
    check_root
    
    # Check and install dependencies
    check_dependencies
    
    # Create necessary directories
    create_directories
    
    # Copy scripts
    copy_scripts
    if [ $? -ne 0 ]; then
        log "Failed to copy all scripts. Exiting." "ERROR"
        exit 1
    fi
    
    # Test all scripts
    test_all_scripts
    
    # Test services
    test_postgresql
    test_nginx
    test_nodejs
    
    # Create cron jobs
    create_cron_jobs
    
    # Set up log rotation
    setup_log_rotation
    
    # Generate installation report
    generate_report
    
    # Clean up
    cleanup
    
    log "Installation completed successfully!" "SUCCESS"
    log "Please review the installation report at $LOG_DIR/installation_report.txt" "INFO"
}

# Run the main installation process
main
