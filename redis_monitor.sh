#!/bin/bash

# Redis Monitoring Script
# Purpose: Monitor Redis performance, memory usage, and connections
# Recommended cron: */10 * * * * /opt/admin/scripts/redis_monitor.sh

# Configuration
LOG_FILE="/var/log/redis_monitor.log"
ALERT_EMAIL="admin@example.com"
REDIS_CLI="/usr/bin/redis-cli"
REDIS_PASSWORD=$(grep "^requirepass" /etc/redis/redis.conf | cut -d " " -f2)
CONNECTIONS_THRESHOLD=100  # Alert if more than 100 connections
MEMORY_THRESHOLD=80  # Alert if more than 80% memory used

# Create auth string with password if configured
if [ -n "$REDIS_PASSWORD" ]; then
    AUTH_PARAM="-a $REDIS_PASSWORD"
else
    AUTH_PARAM=""
fi

# Log start
echo "Redis monitor check: $(date)" >> $LOG_FILE

# Check if Redis is running
if ! systemctl is-active --quiet redis-server; then
    echo "ERROR: Redis is not running!" >> $LOG_FILE
    echo "Redis is not running on $(hostname)" | mail -s "Redis Service Alert" $ALERT_EMAIL
    exit 1
fi

# Get Redis info
INFO=$($REDIS_CLI $AUTH_PARAM info)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get Redis info - authentication issue?" >> $LOG_FILE
    echo "Redis authentication failed on $(hostname)" | mail -s "Redis Authentication Alert" $ALERT_EMAIL
    exit 1
fi

# Parse memory usage
USED_MEMORY=$(echo "$INFO" | grep "used_memory_human:" | cut -d ":" -f2 | tr -d "[:space:]")
USED_MEMORY_PEAK=$(echo "$INFO" | grep "used_memory_peak_human:" | cut -d ":" -f2 | tr -d "[:space:]")
MAX_MEMORY=$(echo "$INFO" | grep "maxmemory_human:" | cut -d ":" -f2 | tr -d "[:space:]")

# If maxmemory is not set (0), get total system memory for reference
if [[ "$MAX_MEMORY" == "0B" || -z "$MAX_MEMORY" ]]; then
    TOTAL_MEMORY=$(free -m | grep "Mem:" | awk '{print $2}')
    MAX_MEMORY="${TOTAL_MEMORY}M"
fi

echo "Memory Usage: $USED_MEMORY / $MAX_MEMORY (Peak: $USED_MEMORY_PEAK)" >> $LOG_FILE

# Parse memory fragmentation ratio
MEM_FRAG_RATIO=$(echo "$INFO" | grep "mem_fragmentation_ratio:" | cut -d ":" -f2 | tr -d "[:space:]")
echo "Memory Fragmentation Ratio: $MEM_FRAG_RATIO" >> $LOG_FILE

# Check if fragmentation is too high (> 1.5)
if (( $(echo "$MEM_FRAG_RATIO > 1.5" | bc -l) )); then
    echo "WARNING: High memory fragmentation detected!" >> $LOG_FILE
    echo "Redis high memory fragmentation ($MEM_FRAG_RATIO) on $(hostname)" | mail -s "Redis Memory Alert" $ALERT_EMAIL
fi

# Parse connection info
CONNECTED_CLIENTS=$(echo "$INFO" | grep "connected_clients:" | cut -d ":" -f2 | tr -d "[:space:]")
REJECTED_CONNECTIONS=$(echo "$INFO" | grep "rejected_connections:" | cut -d ":" -f2 | tr -d "[:space:]")
TOTAL_CONNECTIONS_RECEIVED=$(echo "$INFO" | grep "total_connections_received:" | cut -d ":" -f2 | tr -d "[:space:]")

echo "Connected Clients: $CONNECTED_CLIENTS" >> $LOG_FILE
echo "Rejected Connections: $REJECTED_CONNECTIONS" >> $LOG_FILE
echo "Total Connections Received: $TOTAL_CONNECTIONS_RECEIVED" >> $LOG_FILE

# Alert if too many connections
if [ "$CONNECTED_CLIENTS" -gt "$CONNECTIONS_THRESHOLD" ]; then
    echo "WARNING: High number of Redis connections!" >> $LOG_FILE
    echo "Redis has $CONNECTED_CLIENTS connections on $(hostname)" | mail -s "Redis Connections Alert" $ALERT_EMAIL
fi

# Get slow log entries
echo "Recent Slow Log Entries:" >> $LOG_FILE
$REDIS_CLI $AUTH_PARAM slowlog get 5 >> $LOG_FILE

# Check keyspace
echo "Keyspace Statistics:" >> $LOG_FILE
$REDIS_CLI $AUTH_PARAM info keyspace >> $LOG_FILE

# Check for Redis vulnerabilities
echo "Checking Redis security..." >> $LOG_FILE

# Check if Redis is accessible from outside
EXTERNAL_ACCESS=$($REDIS_CLI -h $(hostname -I | awk '{print $1}') -p 6379 ping 2>&1)
if [[ "$EXTERNAL_ACCESS" == "PONG" ]]; then
    echo "CRITICAL: Redis is accessible from external IP addresses!" >> $LOG_FILE
    echo "Redis is accessible from external networks on $(hostname)" | mail -s "Redis Security Alert" $ALERT_EMAIL
fi

# Check if default Redis port is open to the world
OPEN_PORT=$(netstat -an | grep ':6379' | grep 'LISTEN' | grep -v '127.0.0.1')
if [ -n "$OPEN_PORT" ]; then
    echo "CRITICAL: Redis port 6379 is open to external connections!" >> $LOG_FILE
    echo "Redis port 6379 is publicly accessible on $(hostname)" | mail -s "Redis Security Alert" $ALERT_EMAIL
fi

# Check if password is configured (should be picked up from config at top of script)
if [ -z "$REDIS_PASSWORD" ]; then
    echo "WARNING: Redis is running without password authentication!" >> $LOG_FILE
    echo "Redis is running without password protection on $(hostname)" | mail -s "Redis Security Alert" $ALERT_EMAIL
fi

# Verify non-dangerous commands are disabled
FLUSHALL_DISABLED=$($REDIS_CLI $AUTH_PARAM flushall 2>&1 | grep -c "unknown command")
if [ "$FLUSHALL_DISABLED" -eq 0 ]; then
    echo "WARNING: FLUSHALL command is enabled!" >> $LOG_FILE
    echo "Dangerous Redis commands are enabled on $(hostname)" | mail -s "Redis Security Alert" $ALERT_EMAIL
fi

# Log completion
echo "Redis monitor completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
