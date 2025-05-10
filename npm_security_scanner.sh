#!/bin/bash

# NPM Security Scanner Script
# Purpose: Scan frontend project dependencies for vulnerabilities
# Recommended cron: 0 3 * * * /opt/admin/scripts/npm_security_scanner.sh

# Configuration
LOG_FILE="/var/log/npm_security.log"
ALERT_EMAIL="admin@example.com"
FRONTEND_PROJECTS=("/var/www/vite-app" "/var/www/vue-app")  # Paths to your frontend projects
SEVERITY_THRESHOLD="moderate"  # none, low, moderate, high, critical
LOCKFILE_BACKUP_DIR="/var/backups/npm-lockfiles"

# Log start
echo "NPM security scan started: $(date)" > $LOG_FILE

# Ensure npm is installed
if ! command -v npm &> /dev/null; then
    echo "npm is not installed. Installing..." >> $LOG_FILE
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y nodejs
fi

# Create backup directory for lockfiles
mkdir -p $LOCKFILE_BACKUP_DIR

# Scan each project
for project in "${FRONTEND_PROJECTS[@]}"; do
    if [ -d "$project" ]; then
        echo "Scanning project: $project" >> $LOG_FILE
        
        # Check if package.json exists
        if [ ! -f "$project/package.json" ]; then
            echo "WARNING: No package.json found in $project" >> $LOG_FILE
            continue
        fi
        
        # Backup package-lock.json
        if [ -f "$project/package-lock.json" ]; then
            backup_file="$LOCKFILE_BACKUP_DIR/$(basename $project)-package-lock-$(date +%Y%m%d).json"
            cp "$project/package-lock.json" "$backup_file"
            echo "Backed up package-lock.json to $backup_file" >> $LOG_FILE
        fi

        # Change to project directory
        cd "$project"
        
        # Run npm audit
        echo "Running npm audit for $project..." >> $LOG_FILE
        AUDIT_RESULT=$(npm audit --json)
        
        # Save audit result to a file
        echo "$AUDIT_RESULT" > "$project/npm-audit-result.json"
        
        # Parse the results
        VULNERABILITIES=$(echo "$AUDIT_RESULT" | jq '.vulnerabilities')
        if [ -z "$VULNERABILITIES" ] || [ "$VULNERABILITIES" == "null" ]; then
            echo "No vulnerabilities found in $project" >> $LOG_FILE
        else
            # Count vulnerabilities by severity
            LOW=$(echo "$AUDIT_RESULT" | jq '.metadata.vulnerabilities.low')
            MODERATE=$(echo "$AUDIT_RESULT" | jq '.metadata.vulnerabilities.moderate')
            HIGH=$(echo "$AUDIT_RESULT" | jq '.metadata.vulnerabilities.high')
            CRITICAL=$(echo "$AUDIT_RESULT" | jq '.metadata.vulnerabilities.critical')
            
            echo "Vulnerabilities found in $project:" >> $LOG_FILE
            echo "- Low: $LOW" >> $LOG_FILE
            echo "- Moderate: $MODERATE" >> $LOG_FILE
            echo "- High: $HIGH" >> $LOG_FILE
            echo "- Critical: $CRITICAL" >> $LOG_FILE
            
            # Determine if we should alert based on severity threshold
            SHOULD_ALERT=0
            if [ "$SEVERITY_THRESHOLD" = "none" ]; then
                if [ "$LOW" -gt 0 ] || [ "$MODERATE" -gt 0 ] || [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
                    SHOULD_ALERT=1
                fi
            elif [ "$SEVERITY_THRESHOLD" = "low" ]; then
                if [ "$LOW" -gt 0 ] || [ "$MODERATE" -gt 0 ] || [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
                    SHOULD_ALERT=1
                fi
            elif [ "$SEVERITY_THRESHOLD" = "moderate" ]; then
                if [ "$MODERATE" -gt 0 ] || [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
                    SHOULD_ALERT=1
                fi
            elif [ "$SEVERITY_THRESHOLD" = "high" ]; then
                if [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
                    SHOULD_ALERT=1
                fi
            elif [ "$SEVERITY_THRESHOLD" = "critical" ]; then
                if [ "$CRITICAL" -gt 0 ]; then
                    SHOULD_ALERT=1
                fi
            fi
            
            if [ "$SHOULD_ALERT" -eq 1 ]; then
                # Extract detailed vulnerability info for the email
                VULN_DETAILS=$(echo "$AUDIT_RESULT" | jq -r '.vulnerabilities | to_entries[] | "\(.key): \(.value.severity) - \(.value.name) - \(.value.title)"')
                
                # Send alert email with details
                echo "Security vulnerabilities found in npm dependencies for project $project:" | mail -s "NPM Security Alert for $(hostname)" $ALERT_EMAIL << EOF
Vulnerability Summary:
- Low: $LOW
- Moderate: $MODERATE
- High: $HIGH
- Critical: $CRITICAL

Details:
$VULN_DETAILS

A full audit report has been saved to: $project/npm-audit-result.json

To fix these vulnerabilities, you can run:
cd $project && npm audit fix

For vulnerabilities that require major version updates:
cd $project && npm audit fix --force (use with caution)
EOF
                
                echo "Security alert email sent for $project" >> $LOG_FILE
            fi
            
            # Attempt to fix automatically if configured
            if [ "$CRITICAL" -gt 0 ]; then
                echo "Attempting to fix critical vulnerabilities..." >> $LOG_FILE
                npm audit fix >> $LOG_FILE 2>&1
                
                # Re-run audit to check if fixes were applied
                REAUDIT_RESULT=$(npm audit --json)
                NEW_CRITICAL=$(echo "$REAUDIT_RESULT" | jq '.metadata.vulnerabilities.critical')
                
                if [ "$NEW_CRITICAL" -lt "$CRITICAL" ]; then
                    echo "Successfully fixed some critical vulnerabilities. Remaining: $NEW_CRITICAL" >> $LOG_FILE
                    echo "Critical vulnerabilities were automatically fixed in $project on $(hostname). Remaining: $NEW_CRITICAL" | mail -s "NPM Security Fix Applied" $ALERT_EMAIL
                else
                    echo "Unable to automatically fix critical vulnerabilities. Manual intervention required." >> $LOG_FILE
                fi
            fi
        fi
        
        # Check for outdated packages
        echo "Checking for outdated packages in $project..." >> $LOG_FILE
        OUTDATED=$(npm outdated --json)
        
        if [ -n "$OUTDATED" ] && [ "$OUTDATED" != "{}" ]; then
            echo "Outdated packages found in $project:" >> $LOG_FILE
            echo "$OUTDATED" | jq -r 'to_entries[] | "\(.key): current \(.value.current) -> latest \(.value.latest)"' >> $LOG_FILE
        else
            echo "All packages are up to date in $project" >> $LOG_FILE
        fi
    else
        echo "Project directory not found: $project" >> $LOG_FILE
    fi
done

# Log completion
echo "NPM security scan completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
