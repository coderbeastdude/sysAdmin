#!/bin/bash

# PCI Compliance Checker Script
# Purpose: Check for basic PCI DSS compliance requirements for e-commerce sites
# Recommended cron: 0 1 * * * /opt/admin/scripts/pci_compliance_check.sh

# Configuration
LOG_FILE="/var/log/pci_compliance.log"
ALERT_EMAIL="admin@example.com"
WEBSITE_ROOT="/var/www/example.com/public_html"
NGINX_CONF="/etc/nginx/sites-enabled"
ECOMMERCE_URL="https://example.com"

# Log start
echo "PCI compliance check started: $(date)" > $LOG_FILE

# 1. Check SSL/TLS Configuration
echo "Checking SSL/TLS configuration..." >> $LOG_FILE

# Check SSL certificate expiration
echo "Checking SSL certificate expiration..." >> $LOG_FILE
DOMAIN=$(echo $ECOMMERCE_URL | sed -e 's|^[^/]*//||' -e 's|/.*$||')
CERT_EXPIRY=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( ($CERT_EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

echo "SSL certificate expires in $DAYS_UNTIL_EXPIRY days ($CERT_EXPIRY)" >> $LOG_FILE
if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
    echo "WARNING: SSL certificate expires in less than 30 days!" >> $LOG_FILE
    echo "SSL certificate for $DOMAIN expires in $DAYS_UNTIL_EXPIRY days" | mail -s "PCI Compliance Alert: SSL Certificate" $ALERT_EMAIL
fi

# Check for TLS version (must be 1.2 or higher for PCI compliance)
PROTOCOLS=$(nmap --script ssl-enum-ciphers -p 443 $DOMAIN | grep "TLSv" | awk '{print $1}')
echo "SSL/TLS protocols in use: $PROTOCOLS" >> $LOG_FILE

if echo "$PROTOCOLS" | grep -q "TLSv1\.0\|TLSv1\.1"; then
    echo "CRITICAL: Insecure TLS protocols in use! PCI DSS requires TLS 1.2 or higher." >> $LOG_FILE
    echo "Insecure TLS protocols in use on $DOMAIN. PCI DSS requires TLS 1.2 or higher." | mail -s "PCI Compliance Alert: Insecure TLS" $ALERT_EMAIL
fi

# 2. Check for cardholder data
echo "Checking for potential cardholder data..." >> $LOG_FILE

# Look for files that might contain card data
CARD_PATTERN="[4-6][0-9]\{3\}[ -][0-9]\{4\}[ -][0-9]\{4\}[ -][0-9]\{4\}"
POTENTIAL_CARD_FILES=$(find $WEBSITE_ROOT -type f -name "*.php" -o -name "*.js" -o -name "*.log" | xargs grep -l "$CARD_PATTERN" 2>/dev/null)

if [ -n "$POTENTIAL_CARD_FILES" ]; then
    echo "WARNING: Files potentially containing credit card numbers found!" >> $LOG_FILE
    echo "$POTENTIAL_CARD_FILES" >> $LOG_FILE
    echo "Files potentially containing credit card numbers found on $(hostname):\n\n$POTENTIAL_CARD_FILES" | mail -s "PCI Compliance Alert: Card Data" $ALERT_EMAIL
fi

# 3. Check for secure configuration
echo "Checking security configurations..." >> $LOG_FILE

# Check for HTTP to HTTPS redirection
HTTP_REDIRECT=$(grep -r "return 301 https" $NGINX_CONF)
if [ -z "$HTTP_REDIRECT" ]; then
    echo "WARNING: HTTP to HTTPS redirection not found in Nginx configuration!" >> $LOG_FILE
    echo "HTTP to HTTPS redirection not found in Nginx configuration on $(hostname)" | mail -s "PCI Compliance Alert: HTTP Redirect" $ALERT_EMAIL
fi

# Check for CSP headers
CSP_HEADER=$(grep -r "Content-Security-Policy" $NGINX_CONF)
if [ -z "$CSP_HEADER" ]; then
    echo "WARNING: Content-Security-Policy header not found in Nginx configuration!" >> $LOG_FILE
    echo "Content-Security-Policy header not found in Nginx configuration on $(hostname)" | mail -s "PCI Compliance Alert: CSP Headers" $ALERT_EMAIL
fi

# Check for XSS protection
XSS_HEADER=$(grep -r "X-XSS-Protection" $NGINX_CONF)
if [ -z "$XSS_HEADER" ]; then
    echo "WARNING: X-XSS-Protection header not found in Nginx configuration!" >> $LOG_FILE
    echo "X-XSS-Protection header not found in Nginx configuration on $(hostname)" | mail -s "PCI Compliance Alert: XSS Headers" $ALERT_EMAIL
fi

# 4. Check for secure cookies
echo "Checking cookie security..." >> $LOG_FILE

# Get cookies from site
COOKIES=$(curl -s -I $ECOMMERCE_URL | grep -i "set-cookie")
echo "Cookies found: $COOKIES" >> $LOG_FILE

# Check for secure and httpOnly flags
if [ -n "$COOKIES" ] && ! echo "$COOKIES" | grep -q "secure"; then
    echo "WARNING: Secure flag not set on all cookies!" >> $LOG_FILE
    echo "Secure flag not set on all cookies on $(hostname)" | mail -s "PCI Compliance Alert: Cookie Security" $ALERT_EMAIL
fi

if [ -n "$COOKIES" ] && ! echo "$COOKIES" | grep -q "httpOnly"; then
    echo "WARNING: httpOnly flag not set on all cookies!" >> $LOG_FILE
    echo "httpOnly flag not set on all cookies on $(hostname)" | mail -s "PCI Compliance Alert: Cookie Security" $ALERT_EMAIL
fi

# 5. Check for password policy enforcement
echo "Checking password policy..." >> $LOG_FILE

# This is a simplified check - in reality, you would need to inspect your application's code
PASSWORD_POLICY_FILES=$(find $WEBSITE_ROOT -type f -name "*.php" | xargs grep -l "password.*\(validate\|verify\|check\)" 2>/dev/null)
echo "Files potentially containing password validation:" >> $LOG_FILE
echo "$PASSWORD_POLICY_FILES" >> $LOG_FILE

# 6. Check for file integrity monitoring
echo "Checking file integrity monitoring..." >> $LOG_FILE

# Check if rkhunter is installed and configured
if ! command -v rkhunter &> /dev/null; then
    echo "WARNING: rkhunter not installed for file integrity monitoring!" >> $LOG_FILE
    echo "rkhunter not installed for file integrity monitoring on $(hostname)" | mail -s "PCI Compliance Alert: File Integrity" $ALERT_EMAIL
else
    # Check when rkhunter was last run
    LAST_RUN=$(grep "Scan started" /var/log/rkhunter.log | tail -1)
    echo "Last rkhunter scan: $LAST_RUN" >> $LOG_FILE
    
    # If more than 7 days ago, alert
    LAST_RUN_DATE=$(echo "$LAST_RUN" | awk '{print $1}')
    LAST_RUN_EPOCH=$(date -d "$LAST_RUN_DATE" +%s 2>/dev/null)
    
    if [ -z "$LAST_RUN_EPOCH" ] || [ $(( ($CURRENT_EPOCH - $LAST_RUN_EPOCH) / 86400 )) -gt 7 ]; then
        echo "WARNING: File integrity scan not run in the past 7 days!" >> $LOG_FILE
        echo "File integrity scan not run in the past 7 days on $(hostname)" | mail -s "PCI Compliance Alert: File Integrity" $ALERT_EMAIL
    fi
fi

# 7. Check for payment form iframes
echo "Checking for payment form iframes..." >> $LOG_FILE

# Best practice is to use iframes from payment providers rather than handling cards directly
IFRAME_USAGE=$(find $WEBSITE_ROOT -type f -name "*.php" -o -name "*.html" | xargs grep -l "iframe.*\(payment\|checkout\|credit\|card\)" 2>/dev/null)

if [ -z "$IFRAME_USAGE" ]; then
    echo "WARNING: No payment iframes found. Verify you're not directly handling card data!" >> $LOG_FILE
    echo "No payment iframes found on $(hostname). Verify you're not directly handling card data!" | mail -s "PCI Compliance Alert: Payment Handling" $ALERT_EMAIL
else
    echo "Payment iframes found in:" >> $LOG_FILE
    echo "$IFRAME_USAGE" >> $LOG_FILE
fi

# 8. Check for network segmentation
echo "Checking network segmentation..." >> $LOG_FILE

# Check if database is accessible from external networks
DB_PORT_EXTERNAL=$(netstat -an | grep ":5432 " | grep -v "127.0.0.1")
if [ -n "$DB_PORT_EXTERNAL" ]; then
    echo "CRITICAL: PostgreSQL database is accessible from external networks!" >> $LOG_FILE
    echo "PostgreSQL database is accessible from external networks on $(hostname)" | mail -s "PCI Compliance Alert: Network Segmentation" $ALERT_EMAIL
fi

# Check if Redis is accessible from external networks
REDIS_PORT_EXTERNAL=$(netstat -an | grep ":6379 " | grep -v "127.0.0.1")
if [ -n "$REDIS_PORT_EXTERNAL" ]; then
    echo "CRITICAL: Redis is accessible from external networks!" >> $LOG_FILE
    echo "Redis is accessible from external networks on $(hostname)" | mail -s "PCI Compliance Alert: Network Segmentation" $ALERT_EMAIL
fi

# 9. Check for WAF
echo "Checking Web Application Firewall..." >> $LOG_FILE

# Check if ModSecurity is installed
if ! command -v modsecurity &> /dev/null && ! grep -q "modsecurity" /etc/nginx/nginx.conf; then
    echo "WARNING: ModSecurity WAF not detected!" >> $LOG_FILE
    echo "ModSecurity WAF not detected on $(hostname)" | mail -s "PCI Compliance Alert: WAF" $ALERT_EMAIL
fi

# 10. Check for vulnerability scanning
echo "Checking vulnerability scanning schedule..." >> $LOG_FILE

# Check if regular vulnerability scans are scheduled
SCAN_CRON=$(grep -r "nikto\|wapiti\|owasp" /etc/cron.*)
if [ -z "$SCAN_CRON" ]; then
    echo "WARNING: No scheduled vulnerability scans found!" >> $LOG_FILE
    echo "No scheduled vulnerability scans found on $(hostname)" | mail -s "PCI Compliance Alert: Vulnerability Scanning" $ALERT_EMAIL
fi

# 11. Check for access control
echo "Checking access control..." >> $LOG_FILE

# Check for strong admin directory protection
ADMIN_PROTECTION=$(grep -r "location.*admin" $NGINX_CONF | grep -E "auth_basic|allow|deny")
if [ -z "$ADMIN_PROTECTION" ]; then
    echo "WARNING: No strong protection for admin directories found!" >> $LOG_FILE
    echo "No strong protection for admin directories found on $(hostname)" | mail -s "PCI Compliance Alert: Access Control" $ALERT_EMAIL
fi

# 12. Check logging
echo "Checking logging configuration..." >> $LOG_FILE

# Check if access logs are enabled
ACCESS_LOGS=$(grep -r "access_log" $NGINX_CONF)
if [ -z "$ACCESS_LOGS" ]; then
    echo "WARNING: Nginx access logs not enabled!" >> $LOG_FILE
    echo "Nginx access logs not enabled on $(hostname)" | mail -s "PCI Compliance Alert: Logging" $ALERT_EMAIL
fi

# Check if error logs are enabled
ERROR_LOGS=$(grep -r "error_log" $NGINX_CONF)
if [ -z "$ERROR_LOGS" ]; then
    echo "WARNING: Nginx error logs not enabled!" >> $LOG_FILE
    echo "Nginx error logs not enabled on $(hostname)" | mail -s "PCI Compliance Alert: Logging" $ALERT_EMAIL
fi

# Summarize findings
WARNINGS=$(grep -c "WARNING" $LOG_FILE)
CRITICALS=$(grep -c "CRITICAL" $LOG_FILE)

echo "PCI compliance check completed with $WARNINGS warnings and $CRITICALS critical issues." >> $LOG_FILE

if [ $WARNINGS -gt 0 ] || [ $CRITICALS -gt 0 ]; then
    echo "PCI compliance check on $(hostname) found $WARNINGS warnings and $CRITICALS critical issues. See $LOG_FILE for details." | mail -s "PCI Compliance Summary" $ALERT_EMAIL
fi

# Log completion
echo "PCI compliance check completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE