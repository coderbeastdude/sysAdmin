#!/bin/bash

# msmtp Installation and Configuration Script
# Purpose: Install msmtp and set up basic configuration for system alerts
# Note: You'll need to manually configure server settings

# Log file
LOG_FILE="/var/log/msmtp_setup.log"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

echo "msmtp installation and configuration started: $(date)" > $LOG_FILE

# Install msmtp and dependencies
echo "Installing msmtp and dependencies..." | tee -a $LOG_FILE
apt-get update >> $LOG_FILE 2>&1
apt-get install -y msmtp msmtp-mta mailutils >> $LOG_FILE 2>&1

# Check if installation was successful
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install msmtp" | tee -a $LOG_FILE
    exit 1
fi

echo "msmtp installed successfully" | tee -a $LOG_FILE

# Create basic configuration file
echo "Creating basic configuration file..." | tee -a $LOG_FILE

cat > /etc/msmtprc << 'EOF'
# msmtp Configuration File - System Wide
# Edit this file to add your email server settings

# Set default values for all following accounts
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

# Email server configuration
# Replace with your actual email server settings
account        email-server
host           mail.yourdomain.com
port           587
from           alerts@yourdomain.com
user           alerts@yourdomain.com
password       YOUR_PASSWORD_HERE
tls_starttls   on

# Secondary account (optional) - for different alerts or backup
account        secondary
host           smtp.gmail.com
port           587
from           backup@yourdomain.com
user           backup@yourdomain.com
password       YOUR_BACKUP_PASSWORD_HERE
tls_starttls   on

# Set a default account
account default : email-server
EOF

# Set correct permissions
chmod 600 /etc/msmtprc
chmod 644 /var/log/msmtp.log

echo "Basic configuration file created at /etc/msmtprc" | tee -a $LOG_FILE

# Create a test script
echo "Creating test script..." | tee -a $LOG_FILE

cat > /opt/admin/scripts/test_email.sh << 'EOF'
#!/bin/bash

# Test script for msmtp email functionality

# Default test email address
TEST_EMAIL="admin@yourdomain.com"

# Check if a custom email was provided
if [ -n "$1" ]; then
    TEST_EMAIL="$1"
fi

# Send test email
echo "This is a test email from msmtp on $(hostname)" | \
mail -s "msmtp Test - $(date)" "$TEST_EMAIL"

# Check the status
if [ $? -eq 0 ]; then
    echo "Test email sent successfully to $TEST_EMAIL"
    echo "Check your inbox and also /var/log/msmtp.log for details"
else
    echo "Failed to send test email"
    echo "Check /var/log/msmtp.log for error details"
fi

# Show last few lines of log
echo "Last 5 lines of msmtp log:"
tail -5 /var/log/msmtp.log
EOF

chmod +x /opt/admin/scripts/test_email.sh

echo "Test script created at /opt/admin/scripts/test_email.sh" | tee -a $LOG_FILE

# Create a helper script for sending alerts
echo "Creating alert helper script..." | tee -a $LOG_FILE

cat > /opt/admin/scripts/send_alert.sh << 'EOF'
#!/bin/bash

# Alert Helper Script for Monitoring Scripts
# Usage: send_alert.sh "SEVERITY" "SUBJECT" "MESSAGE" ["EMAIL_ADDRESS"]

# Default alert email
ALERT_EMAIL="admin@yourdomain.com"

# Get arguments
SEVERITY="$1"
SUBJECT="$2"
MESSAGE="$3"
TO_EMAIL="${4:-$ALERT_EMAIL}"

# Add context to the message
FULL_MESSAGE="Server: $(hostname)
Timestamp: $(date)
Severity: ${SEVERITY}

Alert Details:
${MESSAGE}

This is an automated alert from your monitoring system."

# Send email
echo "$FULL_MESSAGE" | mail -s "[${SEVERITY}] ${SUBJECT}" "$TO_EMAIL"

# Log the alert
echo "$(date) - Alert sent: [${SEVERITY}] ${SUBJECT} to ${TO_EMAIL}" >> /var/log/alerts_sent.log
EOF

chmod +x /opt/admin/scripts/send_alert.sh

echo "Alert helper script created at /opt/admin/scripts/send_alert.sh" | tee -a $LOG_FILE

# Create an email alert test for cron jobs
echo "Creating cron email test script..." | tee -a $LOG_FILE

cat > /opt/admin/scripts/test_cron_email.sh << 'EOF'
#!/bin/bash

# This script tests email functionality specifically from cron jobs
# It's designed to be run as a cron job

LOG_FILE="/var/log/cron_email_test.log"

echo "Running cron email test: $(date)" >> $LOG_FILE

# Test basic email sending
echo "This is a test email from a cron job on $(hostname) at $(date)" | \
mail -s "Cron Email Test - $(date)" admin@yourdomain.com

if [ $? -eq 0 ]; then
    echo "SUCCESS: Email sent from cron job" >> $LOG_FILE
else
    echo "ERROR: Failed to send email from cron job" >> $LOG_FILE
fi

# Test alert helper script
/opt/admin/scripts/send_alert.sh "INFO" "Cron Test Alert" "This is a test alert sent from a cron job"

# Show current msmtp configuration status
echo "Current msmtp status:" >> $LOG_FILE
systemctl status msmtp-mta >> $LOG_FILE 2>&1

# Check if credentials are configured
if grep -q "YOUR_PASSWORD_HERE" /etc/msmtprc; then
    echo "WARNING: Default password still in configuration!" >> $LOG_FILE
fi

echo "----------------------------------------" >> $LOG_FILE
EOF

chmod +x /opt/admin/scripts/test_cron_email.sh

echo "Cron email test script created at /opt/admin/scripts/test_cron_email.sh" | tee -a $LOG_FILE

# Create a systemd service for msmtp if needed
echo "Checking systemd configuration..." | tee -a $LOG_FILE

if [ ! -f /etc/systemd/system/msmtp-mta.service ]; then
    cat > /etc/systemd/system/msmtp-mta.service << 'EOF'
[Unit]
Description=msmtp Mail Transport Agent
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable msmtp-mta.service
    echo "Created and enabled msmtp-mta service" | tee -a $LOG_FILE
fi

# Create a setup status check script
echo "Creating setup status check script..." | tee -a $LOG_FILE

cat > /opt/admin/scripts/check_msmtp_status.sh << 'EOF'
#!/bin/bash

# Check msmtp Setup Status

echo "=== msmtp Configuration Status ==="
echo "Date: $(date)"
echo

# Check if msmtp is installed
if command -v msmtp &> /dev/null; then
    echo "✓ msmtp is installed"
    msmtp --version
else
    echo "✗ msmtp is not installed"
fi

echo

# Check configuration file
if [ -f /etc/msmtprc ]; then
    echo "✓ Configuration file exists at /etc/msmtprc"
    
    # Check permissions
    PERMS=$(stat -c %a /etc/msmtprc)
    if [ "$PERMS" = "600" ]; then
        echo "✓ Configuration file has correct permissions (600)"
    else
        echo "✗ Configuration file has incorrect permissions ($PERMS). Should be 600."
    fi
    
    # Check if default password is still present
    if grep -q "YOUR_PASSWORD_HERE" /etc/msmtprc; then
        echo "✗ Default password placeholder still present! Please configure with actual credentials."
        echo "  Edit /etc/msmtprc and replace YOUR_PASSWORD_HERE with your actual password"
    else
        echo "✓ Configuration appears to be customized"
    fi
else
    echo "✗ Configuration file not found at /etc/msmtprc"
fi

echo

# Check log file
if [ -f /var/log/msmtp.log ]; then
    echo "✓ Log file exists at /var/log/msmtp.log"
    echo "  Last 3 log entries:"
    tail -3 /var/log/msmtp.log | sed 's/^/  /'
else
    echo "✗ Log file not found at /var/log/msmtp.log"
fi

echo

# Check helper scripts
SCRIPTS=("/opt/admin/scripts/test_email.sh" "/opt/admin/scripts/send_alert.sh" "/opt/admin/scripts/test_cron_email.sh")

echo "=== Helper Scripts Status ==="
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✓ $script exists and is executable"
    else
        echo "✗ $script not found"
    fi
done

echo

# Check if mail command is working
echo "=== Testing mail command ==="
if command -v mail &> /dev/null; then
    echo "✓ 'mail' command is available"
else
    echo "✗ 'mail' command not found"
fi

echo

# Check systemd service
echo "=== Systemd Service Status ==="
if systemctl list-unit-files | grep -q msmtp-mta; then
    echo "✓ msmtp-mta service is configured"
    systemctl status msmtp-mta.service | grep Active
else
    echo "✗ msmtp-mta service not configured"
fi

echo
echo "=== Next Steps ==="
echo "1. Edit /etc/msmtprc with your email server details"
echo "2. Test email: /opt/admin/scripts/test_email.sh your@email.com"
echo "3. Test cron email: /opt/admin/scripts/test_cron_email.sh"
echo "4. Update monitoring scripts to use the new email configuration"
EOF

chmod +x /opt/admin/scripts/check_msmtp_status.sh

echo "Status check script created at /opt/admin/scripts/check_msmtp_status.sh" | tee -a $LOG_FILE

# Set up basic log rotation for msmtp
echo "Setting up log rotation..." | tee -a $LOG_FILE

cat > /etc/logrotate.d/msmtp << 'EOF'
/var/log/msmtp.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}

/var/log/alerts_sent.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}

/var/log/cron_email_test.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

echo "Log rotation configured" | tee -a $LOG_FILE

# Final summary
echo "msmtp installation and configuration completed: $(date)" | tee -a $LOG_FILE
echo
echo "========================================="
echo "MSMTP INSTALLATION COMPLETE"
echo "========================================="
echo
echo "NEXT STEPS:"
echo "1. Edit /etc/msmtprc with your email server settings"
echo "2. Replace YOUR_PASSWORD_HERE with your actual passwords"
echo "3. Run: /opt/admin/scripts/check_msmtp_status.sh"
echo "4. Test email: /opt/admin/scripts/test_email.sh your@email.com"
echo "5. Test cron email: /opt/admin/scripts/test_cron_email.sh"
echo
echo "Log file: $LOG_FILE"
echo "Configuration file: /etc/msmtprc"
echo
echo "Remember to restart the cron service after configuration:"
echo "sudo systemctl restart cron"
echo
echo "========================================="
