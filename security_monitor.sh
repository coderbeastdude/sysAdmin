#!/bin/bash

# Security Monitoring Script
# Purpose: Monitor for security issues and unauthorized access
# Recommended cron: */30 * * * * /path/to/security_monitor.sh

# Configuration
ALERT_EMAIL="admin@example.com"
LOG_FILE="/var/log/security_monitor.log"
TEMP_FILE=$(mktemp)

echo "Security Check: $(date)" > $TEMP_FILE

# Check for failed login attempts
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log | wc -l)
RECENT_FAILED=$(grep "Failed password" /var/log/auth.log | tail -10)
echo -e "\nFailed login attempts: $FAILED_LOGINS" >> $TEMP_FILE
echo -e "Recent failed attempts:\n$RECENT_FAILED" >> $TEMP_FILE

# Check for successful logins
SUCCESSFUL_LOGINS=$(grep "Accepted " /var/log/auth.log | tail -5)
echo -e "\nRecent successful logins:\n$SUCCESSFUL_LOGINS" >> $TEMP_FILE

# Check for modified system files
echo -e "\nChecking for modified system files..." >> $TEMP_FILE
find /etc -type f -mtime -1 -ls | grep -v "\.dpkg" >> $TEMP_FILE

# Check for unusual processes
echo -e "\nUnusual processes (high CPU/memory):" >> $TEMP_FILE
ps aux | sort -nr -k 3 | head -10 >> $TEMP_FILE

# Check for unusual network connections
echo -e "\nUnusual network connections:" >> $TEMP_FILE
netstat -tuln | grep -v "127.0.0.1" >> $TEMP_FILE

# Check for users with empty passwords
echo -e "\nChecking for users with empty passwords:" >> $TEMP_FILE
EMPTY_PASS=$(grep -E "^[^:]+::.*:.*:.*:.*:" /etc/shadow)
if [ -n "$EMPTY_PASS" ]; then
    echo "WARNING: Users with empty passwords found!" >> $TEMP_FILE
    echo "$EMPTY_PASS" >> $TEMP_FILE
    cat $TEMP_FILE | mail -s "SECURITY ALERT: Empty passwords on $(hostname)" $ALERT_EMAIL
fi

# Check for unauthorized sudo users
echo -e "\nChecking sudo users:" >> $TEMP_FILE
grep -E "^%sudo|^sudo" /etc/sudoers >> $TEMP_FILE
grep -E "^%admin|^admin" /etc/sudoers >> $TEMP_FILE
ls -la /etc/sudoers.d/ >> $TEMP_FILE

# Check for suspicious cron jobs
echo -e "\nChecking for suspicious cron jobs:" >> $TEMP_FILE
find /var/spool/cron -type f -exec ls -la {} \; >> $TEMP_FILE
find /etc/cron.* -type f -exec ls -la {} \; >> $TEMP_FILE

# Log the results
cat $TEMP_FILE >> $LOG_FILE
rm $TEMP_FILE

# Keep log file size reasonable
tail -1000 $LOG_FILE > ${LOG_FILE}.tmp && mv ${LOG_FILE}.tmp $LOG_FILE