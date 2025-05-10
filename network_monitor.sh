#!/bin/bash

# Network Monitoring Script
# Purpose: Monitor network connectivity and performance
# Recommended cron: */10 * * * * /path/to/network_monitor.sh

# Configuration
LOG_FILE="/var/log/network_monitor.log"
ALERT_EMAIL="admin@example.com"
HOSTS_TO_CHECK="google.com cloudflare.com github.com your-api-endpoint.com"
SERVICES_TO_CHECK="80:web 443:https 5432:postgresql"
PING_COUNT=5
PING_TIMEOUT=5

# Log start
echo "Network check started: $(date)" >> $LOG_FILE

# Check internet connectivity
echo "Checking internet connectivity..." >> $LOG_FILE
for host in $HOSTS_TO_CHECK; do
    echo "Pinging $host..." >> $LOG_FILE
    ping_result=$(ping -c $PING_COUNT -W $PING_TIMEOUT $host 2>&1)
    status=$?
    
    if [ $status -eq 0 ]; then
        # Extract average ping time
        avg_ping=$(echo "$ping_result" | grep "avg" | awk -F'/' '{print $5}')
        echo "$host is reachable (avg ping: ${avg_ping}ms)" >> $LOG_FILE
    else
        echo "ERROR: Cannot reach $host!" >> $LOG_FILE
        echo "Network connectivity issue: Cannot reach $host from $(hostname)" | mail -s "Network Alert" $ALERT_EMAIL
    fi
done

# Check for open ports/services
echo "Checking service ports..." >> $LOG_FILE
for service in $SERVICES_TO_CHECK; do
    port=$(echo $service | cut -d: -f1)
    name=$(echo $service | cut -d: -f2)
    
    # Check if the port is listening
    if netstat -tuln | grep ":$port " > /dev/null; then
        echo "Service $name (port $port) is listening" >> $LOG_FILE
    else
        echo "ERROR: Service $name (port $port) is not listening!" >> $LOG_FILE
        echo "Service $name (port $port) is not listening on $(hostname)" | mail -s "Service Port Alert" $ALERT_EMAIL
    fi
done

# Check network interfaces
echo "Checking network interfaces..." >> $LOG_FILE
ifconfig >> $LOG_FILE 2>&1

# Check current connections
echo "Current connections:" >> $LOG_FILE
netstat -tn | grep ESTABLISHED | wc -l >> $LOG_FILE

# Check for high number of connections to PostgreSQL
pg_connections=$(netstat -tn | grep ":5432" | wc -l)
echo "PostgreSQL connections: $pg_connections" >> $LOG_FILE
if [ $pg_connections -gt 50 ]; then
    echo "WARNING: High number of PostgreSQL connections!" >> $LOG_FILE
    echo "High PostgreSQL connection count ($pg_connections) on $(hostname)" | mail -s "Database Connection Alert" $ALERT_EMAIL
fi

# Check for high number of connections to Express
express_connections=$(netstat -tn | grep -E ":(8080)" | wc -l)
echo "Express connections: $express_connections" >> $LOG_FILE
if [ $express_connections -gt 100 ]; then
    echo "WARNING: High number of Express connections!" >> $LOG_FILE
    echo "High Express connection count ($express_connections) on $(hostname)" | mail -s "API Connection Alert" $ALERT_EMAIL
fi

# Log completion
echo "Network check completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
