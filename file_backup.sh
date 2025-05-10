#!/bin/bash

# File System Backup Script
# Purpose: Backup important application files and configurations
# Recommended cron: 0 3 * * * /path/to/file_backup.sh

# Configuration
BACKUP_DIR="/var/backups/files"
SOURCE_DIRS="/var/www /etc/nginx /etc/postgresql /etc/express-app"
RETENTION_DAYS=7
LOG_FILE="/var/log/file_backup.log"
ALERT_EMAIL="admin@example.com"
EXCLUDE_PATTERNS="node_modules/ .git/ .env"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Log start
echo "File backup started: $(date)" >> $LOG_FILE

# Set date format for backup files
DATE=$(date +"%Y-%m-%d")
BACKUP_FILE="$BACKUP_DIR/files_${DATE}.tar.gz"

# Create exclude file
EXCLUDE_FILE=$(mktemp)
for pattern in $EXCLUDE_PATTERNS; do
    echo "$pattern" >> $EXCLUDE_FILE
done

# Perform the backup
echo "Creating backup archive: $BACKUP_FILE" >> $LOG_FILE
tar -czf $BACKUP_FILE --exclude-from=$EXCLUDE_FILE $SOURCE_DIRS 2>> $LOG_FILE

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "File backup completed successfully." >> $LOG_FILE
    
    # Calculate backup size
    BACKUP_SIZE=$(du -h $BACKUP_FILE | cut -f1)
    echo "Backup size: $BACKUP_SIZE" >> $LOG_FILE
else
    echo "ERROR: File backup failed!" >> $LOG_FILE
    echo "File backup failed on $(hostname)" | mail -s "Backup Failure Alert" $ALERT_EMAIL
fi

# Remove temporary exclude file
rm $EXCLUDE_FILE

# Remove old backups
echo "Removing backups older than $RETENTION_DAYS days..." >> $LOG_FILE
find $BACKUP_DIR -type f -name "files_*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Optional: Copy to remote location (uncomment and configure as needed)
# rsync -avz $BACKUP_DIR user@remote-server:/path/to/backup/storage/

# Log completion
echo "File backup completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE