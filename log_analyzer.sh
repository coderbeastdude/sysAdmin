#!/bin/bash

# Log Analysis Script
# Purpose: Analyze logs for errors and security issues
# Recommended cron: 0 1 * * * /path/to/log_analyzer.sh

# Configuration
ALERT_EMAIL="admin@example.com"
LOG_DIR="/var/log"
NGINX_LOG="/var/log/nginx/error.log"
POSTGRESQL_LOG="/var/log/postgresql/postgresql-*.log"
EXPRESS_LOG="/var/log/express-app.log"  # Adjust to your app's log path
REPORT_FILE="/var/log/log_analysis_report.txt"

# Create a new report
echo "Log Analysis Report: $(date)" > $REPORT_FILE
echo "=================================" >> $REPORT_FILE

# Analyze system authentication logs
echo -e "\nSSH Authentication Failures:" >> $REPORT_FILE
grep "Failed password" /var/log/auth.log | tail -20 >> $REPORT_FILE

echo -e "\nSuccessful SSH Logins:" >> $REPORT_FILE
grep "Accepted " /var/log/auth.log | tail -10 >> $REPORT_FILE

# Analyze Nginx logs
if [ -f "$NGINX_LOG" ]; then
    echo -e "\nNginx Errors:" >> $REPORT_FILE
    grep -i "error" $NGINX_LOG | tail -20 >> $REPORT_FILE
    
    echo -e "\nNginx 404 Errors:" >> $REPORT_FILE
    grep -i "404" /var/log/nginx/access.log | tail -10 >> $REPORT_FILE
    
    echo -e "\nPotential Security Issues (Nginx):" >> $REPORT_FILE
    grep -i -E "script|inject|attack|hack|exploit" /var/log/nginx/access.log | tail -20 >> $REPORT_FILE
fi

# Analyze PostgreSQL logs
if ls $POSTGRESQL_LOG 1> /dev/null 2>&1; then
    echo -e "\nPostgreSQL Errors:" >> $REPORT_FILE
    grep -i "error" $POSTGRESQL_LOG | tail -20 >> $REPORT_FILE
    
    echo -e "\nPostgreSQL Slow Queries:" >> $REPORT_FILE
    grep -i "duration" $POSTGRESQL_LOG | tail -10 >> $REPORT_FILE
fi

# Analyze Express application logs
if [ -f "$EXPRESS_LOG" ]; then
    echo -e "\nExpress Application Errors:" >> $REPORT_FILE
    grep -i -E "error|exception|fail" $EXPRESS_LOG | tail -20 >> $REPORT_FILE
fi

# Check for unusual system messages
echo -e "\nUnusual System Messages:" >> $REPORT_FILE
grep -i -E "warning|error|fail|critical" /var/log/syslog | tail -20 >> $REPORT_FILE

# Count total errors by type
echo -e "\nError Summary:" >> $REPORT_FILE
echo "Authentication failures: $(grep "Failed password" /var/log/auth.log | wc -l)" >> $REPORT_FILE
if [ -f "$NGINX_LOG" ]; then
    echo "Nginx errors: $(grep -i "error" $NGINX_LOG | wc -l)" >> $REPORT_FILE
fi
if ls $POSTGRESQL_LOG 1> /dev/null 2>&1; then
    echo "PostgreSQL errors: $(grep -i "error" $POSTGRESQL_LOG | wc -l)" >> $REPORT_FILE
fi
if [ -f "$EXPRESS_LOG" ]; then
    echo "Express app errors: $(grep -i -E "error|exception|fail" $EXPRESS_LOG | wc -l)" >> $REPORT_FILE
fi

# Email the report
cat $REPORT_FILE | mail -s "Log Analysis Report for $(hostname)" $ALERT_EMAIL

