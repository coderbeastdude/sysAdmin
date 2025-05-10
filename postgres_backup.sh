#!/bin/bash

# PostgreSQL Backup Script
# Purpose: Create and manage PostgreSQL database backups
# Recommended cron: 0 2 * * * /path/to/postgres_backup.sh

# Configuration
BACKUP_DIR="/var/backups/postgresql"
RETENTION_DAYS=7
DB_USER="postgres"
DB_PASSWORD="your_password"  # Better to use .pgpass file for security
DATABASES="your_db1 your_db2"  # List databases to backup, or use "all"
LOG_FILE="/var/log/postgres_backup.log"
ALERT_EMAIL="admin@example.com"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Log start
echo "PostgreSQL backup started: $(date)" >> $LOG_FILE

# Set date format for backup files
DATE=$(date +"%Y-%m-%d_%H-%M")

# Backup all databases or specific ones
if [ "$DATABASES" = "all" ]; then
    echo "Backing up all databases..." >> $LOG_FILE
    
    # Get list of all databases
    DB_LIST=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres')" | tr -d ' ')
    
    for DB in $DB_LIST; do
        BACKUP_FILE="$BACKUP_DIR/${DB}_${DATE}.sql.gz"
        echo "Backing up $DB to $BACKUP_FILE" >> $LOG_FILE
        
        # Perform the backup
        sudo -u postgres pg_dump $DB | gzip > $BACKUP_FILE
        
        # Check if backup was successful
        if [ $? -eq 0 ]; then
            echo "Backup of $DB completed successfully." >> $LOG_FILE
        else
            echo "ERROR: Backup of $DB failed!" >> $LOG_FILE
            echo "PostgreSQL backup of $DB failed on $(hostname)" | mail -s "Backup Failure Alert" $ALERT_EMAIL
        fi
    done
else
    # Backup specific databases
    for DB in $DATABASES; do
        BACKUP_FILE="$BACKUP_DIR/${DB}_${DATE}.sql.gz"
        echo "Backing up $DB to $BACKUP_FILE" >> $LOG_FILE
        
        # Perform the backup
        sudo -u postgres pg_dump $DB | gzip > $BACKUP_FILE
        
        # Check if backup was successful
        if [ $? -eq 0 ]; then
            echo "Backup of $DB completed successfully." >> $LOG_FILE
        else
            echo "ERROR: Backup of $DB failed!" >> $LOG_FILE
            echo "PostgreSQL backup of $DB failed on $(hostname)" | mail -s "Backup Failure Alert" $ALERT_EMAIL
        fi
    done
fi

# Remove old backups
echo "Removing backups older than $RETENTION_DAYS days..." >> $LOG_FILE
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Verify backup files exist
BACKUP_COUNT=$(find $BACKUP_DIR -type f -name "*.sql.gz" -mtime -1 | wc -l)
echo "Total backups created today: $BACKUP_COUNT" >> $LOG_FILE

if [ $BACKUP_COUNT -eq 0 ]; then
    echo "WARNING: No backup files were created!" >> $LOG_FILE
    echo "No PostgreSQL backups were created on $(hostname)" | mail -s "Backup Failure Alert" $ALERT_EMAIL
fi

# Log completion
echo "PostgreSQL backup completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE