#!/bin/bash

# PostgreSQL Optimizer Script
# Purpose: Optimize PostgreSQL database performance
# Recommended cron: 0 2 * * 0 /path/to/postgres_optimizer.sh

# Configuration
LOG_FILE="/var/log/postgres_optimizer.log"
ALERT_EMAIL="admin@example.com"
DB_USER="postgres"
VACUUM_THRESHOLD=30  # Vacuum if more than 30% of tuples are dead
ANALYZE_DAYS=7  # Analyze tables not analyzed in the last 7 days

# Log start
echo "PostgreSQL optimization started: $(date)" >> $LOG_FILE

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    echo "ERROR: PostgreSQL is not running!" >> $LOG_FILE
    echo "PostgreSQL is not running on $(hostname)" | mail -s "Database Service Alert" $ALERT_EMAIL
    exit 1
fi

# Get list of databases
DB_LIST=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1')" | tr -d ' ')

# Process each database
for DB in $DB_LIST; do
    echo "Processing database: $DB" >> $LOG_FILE
    
    # Check for tables that need vacuuming
    echo "Checking for tables that need vacuuming in $DB..." >> $LOG_FILE
    TABLES_NEEDING_VACUUM=$(sudo -u postgres psql -d $DB -t -c "SELECT schemaname || '.' || relname, n_dead_tup, n_live_tup, round(n_dead_tup * 100 / (n_live_tup + n_dead_tup)) AS dead_percentage FROM pg_stat_user_tables WHERE n_live_tup > 0 AND round(n_dead_tup * 100 / (n_live_tup + n_dead_tup)) > $VACUUM_THRESHOLD ORDER BY dead_percentage DESC;")
    
    if [ -n "$TABLES_NEEDING_VACUUM" ]; then
        echo "Tables needing vacuum in $DB:" >> $LOG_FILE
        echo "$TABLES_NEEDING_VACUUM" >> $LOG_FILE
        
        # Vacuum analyze the database
        echo "Running VACUUM ANALYZE on $DB..." >> $LOG_FILE
        sudo -u postgres psql -d $DB -c "VACUUM ANALYZE;" >> $LOG_FILE 2>&1
    else
        echo "No tables need vacuuming in $DB." >> $LOG_FILE
    fi
    
    # Check for tables that need analyzing
    echo "Checking for tables that need analyzing in $DB..." >> $LOG_FILE
    TABLES_NEEDING_ANALYZE=$(sudo -u postgres psql -d $DB -t -c "SELECT schemaname || '.' || relname, last_analyze FROM pg_stat_user_tables WHERE last_analyze < NOW() - INTERVAL '$ANALYZE_DAYS days' OR last_analyze IS NULL;")
    
    if [ -n "$TABLES_NEEDING_ANALYZE" ]; then
        echo "Tables needing analyze in $DB:" >> $LOG_FILE
        echo "$TABLES_NEEDING_ANALYZE" >> $LOG_FILE
        
        # Analyze the database
        echo "Running ANALYZE on $DB..." >> $LOG_FILE
        sudo -u postgres psql -d $DB -c "ANALYZE;" >> $LOG_FILE 2>&1
    else
        echo "No tables need analyzing in $DB." >> $LOG_FILE
    fi
    
    # Check for bloated tables
    echo "Checking for bloated tables in $DB..." >> $LOG_FILE
    BLOATED_TABLES=$(sudo -u postgres psql -d $DB -t -c "SELECT schemaname || '.' || tablename, pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size FROM pg_tables ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC LIMIT 10;")
    
    echo "Top 10 largest tables in $DB:" >> $LOG_FILE
    echo "$BLOATED_TABLES" >> $LOG_FILE
    
    # Check for unused indexes
    echo "Checking for unused indexes in $DB..." >> $LOG_FILE
    UNUSED_INDEXES=$(sudo -u postgres psql -d $DB -t -c "SELECT schemaname || '.' || relname AS table, indexrelname AS index, pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size, idx_scan as index_scans FROM pg_stat_user_indexes ui JOIN pg_index i ON ui.indexrelid = i.indexrelid WHERE NOT indisunique AND idx_scan < 50 AND pg_relation_size(i.indexrelid) > 5 * 8192 ORDER BY pg_relation_size(i.indexrelid) DESC LIMIT 10;")
    
    if [ -n "$UNUSED_INDEXES" ]; then
        echo "Potentially unused indexes in $DB:" >> $LOG_FILE
        echo "$UNUSED_INDEXES" >> $LOG_FILE
        echo "Consider removing these indexes if they are not needed." >> $LOG_FILE
    else
        echo "No unused indexes found in $DB." >> $LOG_FILE
    fi
    
    # Check for slow queries
    echo "Checking for slow queries in $DB..." >> $LOG_FILE
    SLOW_QUERIES=$(sudo -u postgres psql -d $DB -t -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 5;")
    
    if [ -n "$SLOW_QUERIES" ]; then
        echo "Top 5 slowest queries in $DB:" >> $LOG_FILE
        echo "$SLOW_QUERIES" >> $LOG_FILE
    else
        echo "No slow query data available. Consider enabling pg_stat_statements extension." >> $LOG_FILE
    fi
done

# Log completion
echo "PostgreSQL optimization completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE