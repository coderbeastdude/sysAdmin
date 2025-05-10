How to Use the Master Setup Script

First, make sure you've run the add_sudo_users.sh script and can log in as a non-root user:
bashsudo ./add_sudo_users.sh

Log in as the non-root user you created and verify you can use sudo:
bashssh username@server_ip
sudo apt update

Clone or copy all the scripts to your server
Run the master setup script:
bashsudo ./master_setup.sh


This script will:

Run the server hardening script
Run the Nginx hardening script
Set up Redis security
Configure the service watchdogs
Copy all scripts to /opt/admin/scripts
Create the cron jobs to run scripts automatically
Set up log rotation
Run initial system checks

What Happens After Setup
After running the setup script, your server will be automatically:

Monitored: The frequent monitoring scripts will check system health, network connections, services status, and security conditions
Maintained: Daily and weekly maintenance tasks will handle backups, log rotation, security scans, and system updates
Protected: Security measures from hardening scripts will protect your server, and ongoing security scans will alert you to new issues
Optimized: Regular database and cache optimization will keep your applications running smoothly

Checking Status
To check the status of your server after setup, you can:

Read the master monitoring report:
bashcat /var/log/system_status_report.txt

Check individual logs for specific components:
bashcat /var/log/system_health_check.log
cat /var/log/redis_monitor.log
cat /var/log/nginx_hardening.log

Verify running services:
bashsudo systemctl status nginx postgresql redis-server

This script applies fundamental security measures to your server
After running this, you'll need to reconnect using port 2222: ssh -p 2222 username@server_ip

Scripts Run Automatically on Schedule
The scripts that should be run automatically according to the cronServerManagmentSetup file are:
Monitoring Scripts (Run Frequently)

system_health_check.sh - Every 15 minutes
service_watchdog.sh - Every 5 minutes
network_monitor.sh - Every 10 minutes
security_monitor.sh - Every 30 minutes
checkout_monitor.sh - Every 10 minutes (for e-commerce)
redis_monitor.sh - Every 10 minutes
go_app_monitor.sh - Every 5 minutes
master_monitor.sh - Hourly (provides summary report)
disk_space_monitor.sh - Every 4 hours

Maintenance Scripts (Run Daily/Weekly)

log_analyzer.sh - Daily at 1 AM
postgres_backup.sh - Daily at 2 AM
file_backup.sh - Daily at 3 AM
cache_cleaner.sh - Daily at 3 AM
ssl_cert_monitor.sh - Daily at midnight
npm_security_scanner.sh - Daily at 3 AM
frontend_build_integrity.sh - Daily at 1 AM
pci_compliance_check.sh - Daily at 1 AM
system_update.sh - Weekly on Sunday at 4 AM
postgres_optimizer.sh - Weekly on Sunday at 2 AM



