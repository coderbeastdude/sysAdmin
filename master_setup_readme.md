# Master Server Setup Guide

This guide walks you through the complete server setup process, from initial user configuration to full monitoring automation.

## Prerequisites

- Fresh Ubuntu server (20.04 LTS or newer recommended)
- Root access to the server
- Basic SSH access configured

## Setup Process Overview

The setup process involves several steps that must be executed in order:

1. **Add Sudo Users** (Manual)
2. **Configure Email System** (Manual)
3. **Run Master Setup Script** (Automated)
4. **Configure Email Alerts** (Manual)
5. **Test and Verify** (Manual)

## Step 1: Add Sudo Users

First, create your non-root administrative users:

```bash
sudo ./add_sudo_users.sh
```

Follow the prompts to:
- Create user accounts
- Set passwords
- Copy SSH keys from root

**Important**: After creating users, log out and log back in as one of the new sudo users:

```bash
# Log out
exit

# Log back in as your new user
ssh username@server_ip

# Test sudo access
sudo apt update
```

## Step 2: Configure Email System

Before running the master setup script, configure msmtp for email alerts:

```bash
sudo ./setup_msmtp.sh
```

After installation, configure your email server settings:

```bash
sudo nano /etc/msmtprc
```

Update these values with your actual email server information:

```
account        email-server
host           mail.yourdomain.com        # Your email server
port           587                        # Usually 587 for TLS
from           alerts@yourdomain.com      # From address for alerts
user           alerts@yourdomain.com      # SMTP username
password       YOUR_ACTUAL_PASSWORD       # Replace with real password
```

**Important**: Set correct permissions:
```bash
sudo chmod 600 /etc/msmtprc
```

Test the email configuration:
```bash
/opt/admin/scripts/test_email.sh your-actual-email@domain.com
```

## Step 3: Configure Email Addresses

### Update Alert Email Address

All monitoring scripts need to be updated with your actual email address. Edit the master setup script before running it to change the default email:

```bash
nano ./master_setup.sh
```

Find and change this line:
```bash
EMAIL="admin@example.com"  # Replace with your actual email
```

To your actual email address:
```bash
EMAIL="your-actual-email@domain.com"  # Your real email address here
```

**Important**: Make sure to save the file after editing.

## Step 4: Run Master Setup Script

Now run the master setup script to configure the server:

```bash
sudo ./master_setup_with_email.sh
```

This script will:
- Apply server hardening
- Configure Nginx with optimizations
- Set up Redis security
- Install all monitoring scripts (with your email address)
- Configure automated backups
- Set up cron jobs for monitoring
- Set up msmtp for email alerts

**Note**: After this step completes, SSH will run on port 2222. Reconnect using:
```bash
ssh -p 2222 username@server_ip
```

### Alternative: Update Scripts After Setup

If you forgot to change the email before running the master setup, update all scripts afterward:

```bash
# Find all scripts with the default email
grep -r "admin@example.com" /opt/admin/scripts/

# Replace all instances
sudo sed -i 's/admin@example.com/your-actual-email@domain.com/g' /opt/admin/scripts/*.sh

# Also update the cron configuration
sudo sed -i 's/admin@example.com/your-actual-email@domain.com/g' /etc/cron.d/server-management
```

## Step 5: Test and Verify

### Test Email Alerts

```bash
# Test basic email
echo "Test from monitoring system" | mail -s "Test Alert" your-actual-email@domain.com

# Test alert helper script
/opt/admin/scripts/send_alert.sh "INFO" "System Test" "This is a test alert"

# Test cron email functionality
/opt/admin/scripts/test_cron_email.sh
```

### Verify Services

```bash
# Check critical services
sudo systemctl status nginx postgresql redis-server

# Check if monitoring scripts are scheduled
cat /etc/cron.d/server-management

# Run a monitoring script manually
/opt/admin/scripts/system_health_check.sh
```

### Check Initial Reports

```bash
# View master monitor report
cat /var/log/system_status_report.txt

# Check security monitor
cat /var/log/security_monitor.log

# View system health
cat /var/log/system_health_check.log
```

## Email Configuration Locations

Here are all the places where you need to set your actual email address:

### 1. Master Setup Script
```bash
# In master_setup.sh
EMAIL="your-actual-email@domain.com"
```

### 2. Individual Monitoring Scripts
Each script in `/opt/admin/scripts/` has an email variable:
```bash
ALERT_EMAIL="your-actual-email@domain.com"
```

### 3. msmtp Configuration
```bash
# In /etc/msmtprc
from           alerts@your-domain.com
user           alerts@your-domain.com
```

### 4. Cron Job Configuration
```bash
# In /etc/cron.d/server-management
# All script outputs are emailed to the specified address
```

## Post-Setup Tasks

### 1. Configure Firewall Rules

Verify UFW settings:
```bash
sudo ufw status verbose
```

Add any additional rules needed for your applications:
```bash
# Example: Allow HTTP/HTTPS for your web server
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 2. Set Up Backups

The scripts are configured, but verify backup destinations:
```bash
# Check backup directories exist
ls -la /var/backups/
```

### 3. Configure SSL Certificates

Set up Let's Encrypt certificates:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 4. Application-Specific Setup

Depending on your stack (Vite/Vue/Go/Postgres/Redis), you'll need to:
- Install Node.js for your frontend builds
- Install Go for your backend applications
- Configure database connections
- Set up Redis connections

## Monitoring Overview

After setup, your server will automatically:

### Frequent Monitoring (Every 5-15 minutes)
- System health checks
- Service status monitoring
- Network connectivity tests
- Redis performance monitoring
- Go application health checks

### Daily Tasks (1-3 AM)
- Log analysis and alerting
- Database backups
- File system backups
- SSL certificate checks
- NPM security scanning
- PCI compliance checks

### Weekly Tasks (Sunday)
- System updates
- Database optimization
- Deep security scans

## Troubleshooting

### Email Not Working

1. Check msmtp configuration:
   ```bash
   /opt/admin/scripts/check_msmtp_status.sh
   ```

2. Test email manually:
   ```bash
   echo "test" | mail -s "test" your-email@domain.com
   ```

3. Check logs:
   ```bash
   tail -f /var/log/msmtp.log
   tail -f /var/log/mail.log
   ```

### SSH Access Issues

If you're locked out after the security hardening:

1. Use your hosting provider's console/VNC
2. Log in as root locally
3. Check firewall settings:
   ```bash
   sudo ufw status
   ```
4. Verify SSH is running on port 2222:
   ```bash
   sudo systemctl status ssh
   sudo netstat -tuln | grep 2222
   ```

### Script Execution Issues

If scripts aren't running via cron:

1. Check cron logs:
   ```bash
   grep -i cron /var/log/syslog
   ```

2. Verify script permissions:
   ```bash
   ls -la /opt/admin/scripts/
   ```

3. Test script execution:
   ```bash
   sudo -u root /opt/admin/scripts/system_health_check.sh
   ```

## Security Notes

### Important Security Configurations

1. **SSH hardening** is applied (port 2222, key-only auth)
2. **Fail2ban** is configured for brute force protection
3. **UFW firewall** is enabled with minimal open ports
4. **Automatic security updates** are enabled
5. **File integrity monitoring** via rkhunter
6. **Log monitoring** for suspicious activity

### Regular Security Tasks

1. Review security logs weekly
2. Update server monthly (automated but review logs)
3. Rotate passwords quarterly
4. Review firewall rules quarterly
5. Audit user accounts semi-annually

## Support and Maintenance

### Log File Locations

- Master monitor: `/var/log/system_status_report.txt`
- Email logs: `/var/log/msmtp.log`
- Security logs: `/var/log/security_monitor.log`
- Service logs: `/var/log/service_watchdog.log`
- All monitoring logs: `/var/log/*_monitor.log`

### Manual Script Execution

Run any monitoring script manually:
```bash
# System health check
/opt/admin/scripts/system_health_check.sh

# Security monitor
/opt/admin/scripts/security_monitor.sh

# Master monitor (comprehensive report)
/opt/admin/scripts/master_monitor.sh
```

### Getting Help

1. Check the log files for detailed error messages
2. Run scripts manually to debug issues
3. Review the individual script documentation
4. Use the status check scripts provided

## Summary

This setup provides a comprehensive, automated monitoring and security system for your server. The key points to remember:

1. **Always use your actual email addresses** in all configurations
2. **Test email functionality** before relying on automated alerts
3. **Review logs regularly** even with automated monitoring
4. **Keep backups current** and test restoration procedures
5. **Update and patch regularly** (automated but monitor the process)

For ongoing maintenance, the automated systems will handle most tasks, but regular review of logs and manual testing ensures everything continues working properly.
