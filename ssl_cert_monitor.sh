#!/bin/bash

# SSL Certificate Monitor Script
# Purpose: Monitor SSL certificate expiration and automate renewal
# Recommended cron: 0 0 * * * /path/to/ssl_cert_monitor.sh

# Configuration
LOG_FILE="/var/log/ssl_cert_monitor.log"
ALERT_EMAIL="admin@example.com"
DOMAINS="example.com www.example.com api.example.com"
CERT_DIR="/etc/letsencrypt/live"
WARNING_DAYS=14  # Send warning if certificate expires within 14 days
CRITICAL_DAYS=7  # Send critical alert if certificate expires within 7 days

# Log start
echo "SSL certificate check started: $(date)" >> $LOG_FILE

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..." >> $LOG_FILE
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Function to check certificate expiration
check_cert_expiration() {
    local domain=$1
    local cert_file="$CERT_DIR/$domain/cert.pem"
    
    # Check if certificate exists
    if [ ! -f "$cert_file" ]; then
        echo "Certificate for $domain not found at $cert_file" >> $LOG_FILE
        return 1
    fi
    
    # Get expiration date
    local expiration_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
    local expiration_epoch=$(date -d "$expiration_date" +%s)
    local current_epoch=$(date +%s)
    local seconds_until_expiry=$((expiration_epoch - current_epoch))
    local days_until_expiry=$((seconds_until_expiry / 86400))
    
    echo "$domain expires in $days_until_expiry days ($expiration_date)" >> $LOG_FILE
    
    # Check if certificate is nearing expiration
    if [ $days_until_expiry -le $CRITICAL_DAYS ]; then
        echo "CRITICAL: Certificate for $domain expires in $days_until_expiry days!" >> $LOG_FILE
        echo "Certificate for $domain expires in $days_until_expiry days on $(hostname)" | mail -s "CRITICAL: SSL Certificate Expiration" $ALERT_EMAIL
        return 2
    elif [ $days_until_expiry -le $WARNING_DAYS ]; then
        echo "WARNING: Certificate for $domain expires in $days_until_expiry days." >> $LOG_FILE
        echo "Certificate for $domain expires in $days_until_expiry days on $(hostname)" | mail -s "WARNING: SSL Certificate Expiration" $ALERT_EMAIL
        return 3
    fi
    
    return 0
}

# Check each domain
for domain in $DOMAINS; do
    echo "Checking certificate for $domain..." >> $LOG_FILE
    check_cert_expiration $domain
    status=$?
    
    # If certificate is nearing expiration or doesn't exist, try to renew/obtain
    if [ $status -ne 0 ]; then
        echo "Attempting to renew certificate for $domain..." >> $LOG_FILE
        certbot --nginx -d $domain --non-interactive --agree-tos --email $ALERT_EMAIL >> $LOG_FILE 2>&1
        
        if [ $? -eq 0 ]; then
            echo "Successfully renewed certificate for $domain." >> $LOG_FILE
            echo "SSL certificate for $domain was successfully renewed on $(hostname)" | mail -s "SSL Certificate Renewal Success" $ALERT_EMAIL
        else
            echo "ERROR: Failed to renew certificate for $domain!" >> $LOG_FILE
            echo "Failed to renew SSL certificate for $domain on $(hostname)" | mail -s "SSL Certificate Renewal Failure" $ALERT_EMAIL
        fi
    fi
done

# Run certbot renew to catch any other certificates
echo "Running general certificate renewal check..." >> $LOG_FILE
certbot renew --quiet >> $LOG_FILE 2>&1

# Reload web server if any certificates were renewed
if [ $? -eq 0 ]; then
    echo "Reloading web server..." >> $LOG_FILE
    systemctl reload nginx >> $LOG_FILE 2>&1
fi

# Log completion
echo "SSL certificate check completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
