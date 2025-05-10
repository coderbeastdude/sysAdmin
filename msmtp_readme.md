# msmtp Email Configuration for Monitoring Scripts

This guide covers the installation, configuration, and testing of msmtp for sending email alerts from your monitoring scripts.

## Installation

Run the installation script as root:

```bash
sudo ./setup_msmtp.sh
```

This script will:
- Install msmtp and necessary dependencies
- Create basic configuration files
- Set up helper scripts for sending alerts
- Configure log rotation
- Create test scripts

## Configuration Steps

### 1. Edit the msmtp Configuration File

After installation, you need to configure msmtp with your email server details:

```bash
sudo nano /etc/msmtprc
```

Replace the placeholder values with your actual email server settings:

```
# Basic email server configuration
account        email-server
host           mail.yourdomain.com        # Your email server hostname/IP
port           587                        # SMTP port (587 for TLS, 465 for SSL, 25 for unencrypted)
from           alerts@yourdomain.com      # From address for alerts
user           alerts@yourdomain.com      # SMTP username
password       YOUR_ACTUAL_PASSWORD       # Replace with actual password
tls_starttls   on                         # Use TLS (change to tls_ssl if using port 465)
```

### 2. Set Correct Permissions

The configuration file contains passwords, so it should be readable only by root:

```bash
sudo chmod 600 /etc/msmtprc
```

### 3. Test Your Configuration

Use the provided test scripts to verify email is working:

```bash
# Test basic email sending
/opt/admin/scripts/test_email.sh your@email.com

# Check msmtp status
/opt/admin/scripts/check_msmtp_status.sh

# Test email from a cron-like environment
/opt/admin/scripts/test_cron_email.sh
```

## Integration with Monitoring Scripts

### Option 1: Using the Helper Script

Use the provided alert helper script in your monitoring scripts:

```bash
# In your monitoring script, replace:
echo "Error message" | mail -s "Alert Subject" admin@yourdomain.com

# With:
/opt/admin/scripts/send_alert.sh "CRITICAL" "Service Down" "PostgreSQL service is not responding"
```

### Option 2: Update Scripts to Use mail Command

Since msmtp provides the `mail` command, your existing monitoring scripts should work without modification. Just ensure they use the correct email address.

## Troubleshooting

### Common Issues and Solutions

1. **Password Authentication Failed**
   ```bash
   # Check the log file
   tail -f /var/log/msmtp.log
   ```
   - Verify your username and password are correct
   - Some email providers require app-specific passwords (Gmail, Outlook)
   - Ensure you're using the correct SMTP port and TLS settings

2. **Connection Issues**
   ```bash
   # Test connectivity to your mail server
   telnet mail.yourdomain.com 587
   ```
   - Verify your email server hostname is correct
   - Check if the port is open (firewall issues)
   - Ensure your email server accepts SMTP connections

3. **Cron Jobs Not Sending Email**
   ```bash
   # Test cron environment
   /opt/admin/scripts/test_cron_email.sh
   
   # Check cron logs
   grep -i cron /var/log/syslog
   ```
   - Ensure msmtp is in the PATH for cron jobs
   - Verify the mail command is available: `which mail`

4. **Permission Errors**
   ```bash
   # Check file permissions
   ls -la /etc/msmtprc
   ls -la /var/log/msmtp.log
   ```
   - Configuration file: should be 600 (read/write for root only)
   - Log file: should be 644 (readable by all, writable by root)

### Log Files

Important log files to check:

- `/var/log/msmtp.log` - msmtp activity log
- `/var/log/mail.log` - System mail log
- `/var/log/cron_email_test.log` - Cron email test results
- `/var/log/alerts_sent.log` - Alert helper script log

## Advanced Configuration

### Multiple Email Accounts

You can configure multiple accounts for different purposes:

```bash
# In /etc/msmtprc, add additional accounts:
account        critical-alerts
host           mail.yourdomain.com
...

account        info-alerts
host           mail.yourdomain.com
...

# Set different defaults for different scripts
account default : critical-alerts
```

### Email Server Settings by Provider

#### Gmail
```
host           smtp.gmail.com
port           587
tls_starttls   on
# Note: Use app password, not your regular Gmail password
```

#### Outlook/Hotmail
```
host           smtp-mail.outlook.com
port           587
tls_starttls   on
```

#### Yahoo
```
host           smtp.mail.yahoo.com
port           465
tls_ssl        on
```

### Custom Email Templates

Create custom templates for different alert types:

```bash
# Create a template directory
sudo mkdir -p /opt/admin/email-templates

# Create templates for different alert types
cat > /opt/admin/email-templates/critical.tmpl << 'EOF'
CRITICAL ALERT - Immediate Action Required

Server: %HOSTNAME%
Time: %TIMESTAMP%
Service: %SERVICE%

Issue: %MESSAGE%

Please investigate immediately.
EOF
```

## Monitoring Script Integration Examples

### Example 1: PostgreSQL Backup Script

```bash
# In postgres_backup.sh
if [ $? -eq 0 ]; then
    echo "Backup completed successfully." >> $LOG_FILE
else
    /opt/admin/scripts/send_alert.sh "CRITICAL" "PostgreSQL Backup Failed" "Backup of database $DB failed on $(hostname)"
fi
```

### Example 2: System Health Check

```bash
# In system_health_check.sh
if [ "$ALERT" = "1" ]; then
    /opt/admin/scripts/send_alert.sh "WARNING" "System Health Issues" "$(cat $TEMP_FILE)"
fi
```

### Example 3: Service Watchdog

```bash
# In service_watchdog.sh
echo "$service was down and has been restarted on $(hostname)" | mail -s "Service Restart Notification" $ALERT_EMAIL
```

## Security Best Practices

1. **Use app-specific passwords** when available (Gmail, Outlook)
2. **Limit network access** to your email server's SMTP port
3. **Rotate passwords** regularly
4. **Monitor email sending** patterns for unusual activity
5. **Use TLS/SSL** for all connections (never send plain text)

## Testing Checklist

Before deploying to production:

- [ ] Basic email sending works
- [ ] Cron jobs can send email
- [ ] Monitoring scripts successfully send alerts
- [ ] Log files are created and rotated
- [ ] Error conditions generate appropriate alerts
- [ ] Email delivery is reliable
- [ ] Passwords are secured (not in scripts or logs)

## Maintenance

### Regular Tasks

1. **Review logs** weekly for errors or unusual activity
2. **Test email delivery** monthly
3. **Update passwords** quarterly
4. **Check certificate expiration** for TLS/SSL
5. **Verify backup email routes** are working

### Backup Configuration

Always backup your configuration:

```bash
# Backup msmtp configuration
sudo cp /etc/msmtprc /path/to/backup/location/

# Backup helper scripts
tar -czf msmtp-helpers-backup.tar.gz /opt/admin/scripts/send_alert.sh /opt/admin/scripts/test_*.sh
```

## Troubleshooting Commands Cheat Sheet

```bash
# Check msmtp version and configuration
msmtp --version
msmtp --help

# Test configuration syntax
msmtp --serverinfo --host=mail.yourdomain.com --port=587 --account=email-server

# Send test email with debug output
echo "Test" | msmtp -d -a email-server recipient@domain.com

# Monitor logs in real-time
tail -f /var/log/msmtp.log

# Check if mail queue is processing
mailq

# Flush mail queue
sudo postsuper -f
```

## Additional Resources

- [msmtp Manual](https://marlam.de/msmtp/msmtp.html)
- [Ubuntu Wiki - msmtp](https://help.ubuntu.com/community/msmtp)
- [ArchWiki - msmtp](https://wiki.archlinux.org/title/Msmtp)

For issues not covered in this guide, check the msmtp log files first, then consult the official documentation.
