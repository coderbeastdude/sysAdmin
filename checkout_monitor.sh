#!/bin/bash

# E-commerce Checkout Behavior Monitor
# Purpose: Monitor and alert on suspicious checkout activity
# Recommended cron: */10 * * * * /opt/admin/scripts/checkout_monitor.sh

# Configuration
LOG_FILE="/var/log/checkout_monitor.log"
ALERT_EMAIL="admin@example.com"
NGINX_ACCESS_LOG="/var/log/nginx/access_example.com.log"
API_LOG="/var/log/express-app.log"  # Your app's API log
DB_USER="postgres"
DB_NAME="ecommerce"
MAX_CHECKOUT_PER_IP=10  # Maximum checkout attempts per IP in timeframe
MAX_FAILED_PAYMENTS=5   # Maximum failed payments per IP in timeframe
TIMEFRAME_MINUTES=30    # Timeframe to monitor (minutes)
IP_BLACKLIST="/etc/nginx/conf.d/ip_blacklist.conf"  # Nginx blacklist config

# Log start
echo "Checkout behavior monitor started: $(date)" > $LOG_FILE

# Ensure required tools are available
if ! command -v jq &> /dev/null; then
    apt-get update && apt-get install -y jq
fi

# 1. Monitor rapid checkout attempts from same IP
echo "Checking for rapid checkout attempts..." >> $LOG_FILE

# Parse Nginx access logs for checkout endpoint access
CHECKOUT_ENDPOINT="/api/checkout"  # Your checkout API endpoint
TIMEFRAME_SEC=$((TIMEFRAME_MINUTES * 60))
CURRENT_TIME=$(date +%s)

# Get checkout attempts by IP in last timeframe
CHECKOUT_ATTEMPTS=$(grep "$CHECKOUT_ENDPOINT" $NGINX_ACCESS_LOG | 
                   awk -v timeframe="$TIMEFRAME_SEC" -v current="$CURRENT_TIME" '
                   {
                     # Parse timestamp
                     gsub(/\[|\]/, "", $4);
                     cmd = "date -d\""$4"\" +%s";
                     cmd | getline timestamp;
                     close(cmd);
                     
                     # If within timeframe, count this attempt
                     if (current - timestamp <= timeframe) {
                       ip_count[$1]++;
                     }
                   }
                   END {
                     # Output IPs with count exceeding threshold
                     for (ip in ip_count) {
                       if (ip_count[ip] >= '$MAX_CHECKOUT_PER_IP') {
                         print ip " " ip_count[ip];
                       }
                     }
                   }')

if [ -n "$CHECKOUT_ATTEMPTS" ]; then
    echo "WARNING: IPs with excessive checkout attempts detected:" >> $LOG_FILE
    echo "$CHECKOUT_ATTEMPTS" >> $LOG_FILE
    
    # Extract IPs for potential blocking
    SUSPICIOUS_IPS=$(echo "$CHECKOUT_ATTEMPTS" | awk '{print $1}')
    
    # Add to summary for email alert
    SUMMARY="Suspicious checkout activity detected:\n\n$CHECKOUT_ATTEMPTS"
else
    echo "No suspicious checkout attempts detected" >> $LOG_FILE
fi

# 2. Monitor for failed payment attempts
echo "Checking for failed payment attempts..." >> $LOG_FILE

# Parse API logs for payment failures
# This assumes your application logs payment failures with specific text
PAYMENT_FAILURES=$(grep "payment.*failed\|transaction.*declined" $API_LOG | 
                  grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | 
                  sort | uniq -c | sort -nr)

if [ -n "$PAYMENT_FAILURES" ]; then
    echo "Payment failures detected:" >> $LOG_FILE
    echo "$PAYMENT_FAILURES" >> $LOG_FILE
    
    # Extract IPs with excessive failed payments
    EXCESSIVE_FAILURES=$(echo "$PAYMENT_FAILURES" | awk '$1 >= '$MAX_FAILED_PAYMENTS' {print $2 " " $1}')
    
    if [ -n "$EXCESSIVE_FAILURES" ]; then
        echo "WARNING: IPs with excessive payment failures:" >> $LOG_FILE
        echo "$EXCESSIVE_FAILURES" >> $LOG_FILE
        
        # Add to summary for email alert
        if [ -n "$SUMMARY" ]; then
            SUMMARY="$SUMMARY\n\nExcessive payment failures:\n$EXCESSIVE_FAILURES"
        else
            SUMMARY="Excessive payment failures detected:\n\n$EXCESSIVE_FAILURES"
        fi
        
        # Merge with suspicious IPs list
        SUSPICIOUS_IPS="$SUSPICIOUS_IPS $(echo "$EXCESSIVE_FAILURES" | awk '{print $1}')"
    fi
else
    echo "No payment failures detected" >> $LOG_FILE
fi

# 3. Check database for suspicious order patterns
echo "Checking for suspicious order patterns in database..." >> $LOG_FILE

# Query PostgreSQL for suspicious patterns
# Adjust the SQL query based on your database schema
if command -v psql &> /dev/null; then
    # Multiple different cards used from same IP
    MULTI_CARD_ORDERS=$(sudo -u postgres psql -d $DB_NAME -t -c "
    SELECT ip_address, COUNT(DISTINCT payment_method_id) AS card_count 
    FROM orders 
    WHERE created_at > NOW() - INTERVAL '$TIMEFRAME_MINUTES minutes'
    GROUP BY ip_address 
    HAVING COUNT(DISTINCT payment_method_id) > 3;")
    
    if [ -n "$MULTI_CARD_ORDERS" ]; then
        echo "WARNING: IPs using multiple payment methods:" >> $LOG_FILE
        echo "$MULTI_CARD_ORDERS" >> $LOG_FILE
        
        # Add to summary for email alert
        if [ -n "$SUMMARY" ]; then
            SUMMARY="$SUMMARY\n\nMultiple payment methods from same IP:\n$MULTI_CARD_ORDERS"
        else
            SUMMARY="Multiple payment methods from same IP detected:\n\n$MULTI_CARD_ORDERS"
        fi
        
        # Extract IPs
        MULTI_CARD_IPS=$(echo "$MULTI_CARD_ORDERS" | awk '{print $1}')
        SUSPICIOUS_IPS="$SUSPICIOUS_IPS $MULTI_CARD_IPS"
    else
        echo "No suspicious multi-card usage detected" >> $LOG_FILE
    fi
    
    # Large quantity of same item purchased
    BULK_PURCHASES=$(sudo -u postgres psql -d $DB_NAME -t -c "
    SELECT ip_address, product_id, SUM(quantity) as total_quantity 
    FROM order_items 
    JOIN orders ON order_items.order_id = orders.id
    WHERE orders.created_at > NOW() - INTERVAL '$TIMEFRAME_MINUTES minutes'
    GROUP BY ip_address, product_id 
    HAVING SUM(quantity) > 10;")
    
    if [ -n "$BULK_PURCHASES" ]; then
        echo "WARNING: Bulk purchases detected:" >> $LOG_FILE
        echo "$BULK_PURCHASES" >> $LOG_FILE
        
        # Add to summary for email alert
        if [ -n "$SUMMARY" ]; then
            SUMMARY="$SUMMARY\n\nBulk purchases:\n$BULK_PURCHASES"
        else
            SUMMARY="Bulk purchases detected:\n\n$BULK_PURCHASES"
        fi
    else
        echo "No suspicious bulk purchases detected" >> $LOG_FILE
    fi
fi

# 4. Check for account creation and immediate checkout
echo "Checking for new accounts with immediate checkout..." >> $LOG_FILE

# This requires application-specific logging or database queries
# Example SQL (adjust based on your schema):
if command -v psql &> /dev/null; then
    NEW_ACCOUNT_CHECKOUTS=$(sudo -u postgres psql -d $DB_NAME -t -c "
    SELECT users.ip_address, users.email, orders.id
    FROM users
    JOIN orders ON users.id = orders.user_id
    WHERE users.created_at > NOW() - INTERVAL '30 minutes'
    AND orders.created_at - users.created_at < INTERVAL '5 minutes';")
    
    if [ -n "$NEW_ACCOUNT_CHECKOUTS" ]; then
        echo "WARNING: New accounts with immediate checkout:" >> $LOG_FILE
        echo "$NEW_ACCOUNT_CHECKOUTS" >> $LOG_FILE
        
        # Add to summary for email alert
        if [ -n "$SUMMARY" ]; then
            SUMMARY="$SUMMARY\n\nNew accounts with immediate checkout:\n$NEW_ACCOUNT_CHECKOUTS"
        else
            SUMMARY="New accounts with immediate checkout detected:\n\n$NEW_ACCOUNT_CHECKOUTS"
        fi
        
        # Extract IPs
        NEW_ACCOUNT_IPS=$(echo "$NEW_ACCOUNT_CHECKOUTS" | awk '{print $1}')
        SUSPICIOUS_IPS="$SUSPICIOUS_IPS $NEW_ACCOUNT_IPS"
    else
        echo "No suspicious new account checkouts detected" >> $LOG_FILE
    fi
fi

# 5. Take action on suspicious IPs
if [ -n "$SUSPICIOUS_IPS" ]; then
    echo "Taking action on suspicious IPs..." >> $LOG_FILE
    
    # Remove duplicates and known false positives
    FILTERED_IPS=$(echo "$SUSPICIOUS_IPS" | tr ' ' '\n' | sort | uniq | grep -v "127.0.0.1\|your.trusted.ip")
    
    if [ -n "$FILTERED_IPS" ]; then
        echo "IPs identified for potential blocking:" >> $LOG_FILE
        echo "$FILTERED_IPS" >> $LOG_FILE
        
        # Option 1: Automatically block IPs in Nginx
        # Uncomment to enable automatic blocking (use with caution)
        #for IP in $FILTERED_IPS; do
        #    if ! grep -q "$IP" $IP_BLACKLIST; then
        #        echo "deny $IP;" >> $IP_BLACKLIST
        #        echo "Blocked IP: $IP" >> $LOG_FILE
        #    fi
        #done
        
        # Option 2: Send alert email with suspicious IPs
        echo -e "$SUMMARY\n\nConsider blocking these IPs:\n$FILTERED_IPS" | mail -s "E-commerce Suspicious Activity Alert" $ALERT_EMAIL
        
        # Reload Nginx if blacklist was updated
        #nginx -t && systemctl reload nginx
    fi
else
    echo "No suspicious IPs identified" >> $LOG_FILE
fi

# Log completion
echo "Checkout behavior monitoring completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
