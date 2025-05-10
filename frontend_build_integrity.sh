#!/bin/bash

# Frontend Build Integrity Checker
# Purpose: Validate the integrity of frontend builds and check for suspicious files
# Recommended cron: Daily after deployments or 0 1 * * * /opt/admin/scripts/frontend_build_integrity.sh

# Configuration
LOG_FILE="/var/log/frontend_integrity.log"
ALERT_EMAIL="admin@example.com"
DIST_DIR="/var/www/app/dist"  # Distribution directory of your built frontend
CHECKSUM_DIR="/var/backups/frontend-checksums"
SUSPICIOUS_PATTERNS=(
    "eval\s*\(" 
    "document\.write\s*\(" 
    "\.innerHTML\s*=" 
    "localStorage\.[gs]etItem" 
    "\.appendChild\s*\(" 
    "new Function\s*\("
    "dangerouslySetInnerHTML"
    "Object\.assign"
    "\\<iframe"
)
EXCLUDED_FILES=("*.map")  # Files to exclude from scanning

# Log start
echo "Frontend build integrity check started: $(date)" > $LOG_FILE

# Create checksum directory if it doesn't exist
mkdir -p $CHECKSUM_DIR

# Check if dist directory exists
if [ ! -d "$DIST_DIR" ]; then
    echo "ERROR: Distribution directory not found: $DIST_DIR" >> $LOG_FILE
    echo "Frontend build directory not found on $(hostname)" | mail -s "Frontend Integrity Alert" $ALERT_EMAIL
    exit 1
fi

# Function to calculate file checksum
calculate_checksums() {
    local dir=$1
    local output_file=$2
    
    find $dir -type f -name "*.js" -o -name "*.css" -o -name "*.html" | sort | xargs md5sum > $output_file
}

# Current timestamp for this run
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
CURRENT_CHECKSUM_FILE="$CHECKSUM_DIR/checksums-$TIMESTAMP.md5"

# Calculate checksums for current build
echo "Calculating checksums for current build..." >> $LOG_FILE
calculate_checksums $DIST_DIR $CURRENT_CHECKSUM_FILE

# Find most recent previous checksum file
PREVIOUS_CHECKSUM_FILE=$(find $CHECKSUM_DIR -name "checksums-*.md5" -not -name "checksums-$TIMESTAMP.md5" | sort -r | head -1)

# Compare with previous build if available
if [ -n "$PREVIOUS_CHECKSUM_FILE" ]; then
    echo "Comparing with previous build checksums: $PREVIOUS_CHECKSUM_FILE" >> $LOG_FILE
    
    # Check for added files
    ADDED_FILES=$(diff --new-line-format='+%L' --old-line-format='' --unchanged-line-format='' \
                 $PREVIOUS_CHECKSUM_FILE $CURRENT_CHECKSUM_FILE | grep "+" | sed 's/^+//')
    
    if [ -n "$ADDED_FILES" ]; then
        echo "New files found since last build:" >> $LOG_FILE
        echo "$ADDED_FILES" >> $LOG_FILE
    else
        echo "No new files found since last build" >> $LOG_FILE
    fi
    
    # Check for removed files
    REMOVED_FILES=$(diff --new-line-format='' --old-line-format='-%L' --unchanged-line-format='' \
                   $PREVIOUS_CHECKSUM_FILE $CURRENT_CHECKSUM_FILE | grep "-" | sed 's/^-//')
    
    if [ -n "$REMOVED_FILES" ]; then
        echo "Files removed since last build:" >> $LOG_FILE
        echo "$REMOVED_FILES" >> $LOG_FILE
    else
        echo "No files removed since last build" >> $LOG_FILE
    fi
    
    # Check for modified files
    MODIFIED_FILES=$(comm -3 <(sort $PREVIOUS_CHECKSUM_FILE | awk '{print $2}') <(sort $CURRENT_CHECKSUM_FILE | awk '{print $2}') | \
                    xargs -I{} grep {} $CURRENT_CHECKSUM_FILE)
    
    if [ -n "$MODIFIED_FILES" ]; then
        echo "Modified files since last build:" >> $LOG_FILE
        echo "$MODIFIED_FILES" >> $LOG_FILE
    else
        echo "No files were modified since last build" >> $LOG_FILE
    fi
else
    echo "No previous build checksums found. This is the first integrity check." >> $LOG_FILE
fi

# Scan for suspicious patterns in JavaScript files
echo "Scanning for suspicious patterns in JavaScript files..." >> $LOG_FILE

SUSPICIOUS_FILES=""
for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
    echo "Checking pattern: $pattern" >> $LOG_FILE
    
    # Use grep to find matches, excluding source maps and any excluded files
    FOUND=$(find $DIST_DIR -type f -name "*.js" -not -path "*/node_modules/*" | grep -v "\.map$" | \
           xargs grep -l "$pattern" 2>/dev/null)
    
    if [ -n "$FOUND" ]; then
        echo "Found suspicious pattern '$pattern' in files:" >> $LOG_FILE
        echo "$FOUND" >> $LOG_FILE
        SUSPICIOUS_FILES="$SUSPICIOUS_FILES\n$FOUND"
    fi
done

# Check for abnormally large files
echo "Checking for abnormally large files..." >> $LOG_FILE
LARGE_FILES=$(find $DIST_DIR -type f -size +500k | grep -v "\.map$")

if [ -n "$LARGE_FILES" ]; then
    echo "Found unusually large files:" >> $LOG_FILE
    echo "$LARGE_FILES" >> $LOG_FILE
fi

# Check for unexpected minified files in source directories
echo "Checking for unexpected minified files..." >> $LOG_FILE
UNEXPECTED_MIN=$(find $DIST_DIR/src -name "*.min.js" 2>/dev/null)

if [ -n "$UNEXPECTED_MIN" ]; then
    echo "Found unexpected minified files in source directories:" >> $LOG_FILE
    echo "$UNEXPECTED_MIN" >> $LOG_FILE
fi

# Check for integrity attributes in script tags
echo "Checking for integrity attributes in HTML files..." >> $LOG_FILE
MISSING_INTEGRITY=$(find $DIST_DIR -name "*.html" -exec grep -l "<script src=\"http" {} \; | \
                  xargs grep -L "integrity=" 2>/dev/null)

if [ -n "$MISSING_INTEGRITY" ]; then
    echo "Found external scripts without integrity attributes:" >> $LOG_FILE
    echo "$MISSING_INTEGRITY" >> $LOG_FILE
fi

# Send alert if suspicious patterns found
if [ -n "$SUSPICIOUS_FILES" ] || [ -n "$LARGE_FILES" ] || [ -n "$UNEXPECTED_MIN" ]; then
    echo "WARNING: Suspicious patterns or files detected in frontend build" >> $LOG_FILE
    
    # Send email alert
    {
        echo "Suspicious patterns or files were detected in the frontend build on $(hostname):"
        
        if [ -n "$SUSPICIOUS_FILES" ]; then
            echo -e "\nFiles with suspicious code patterns:$SUSPICIOUS_FILES"
        fi
        
        if [ -n "$LARGE_FILES" ]; then
            echo -e "\nUnusually large files:\n$LARGE_FILES"
        fi
        
        if [ -n "$UNEXPECTED_MIN" ]; then
            echo -e "\nUnexpected minified files in source directories:\n$UNEXPECTED_MIN"
        fi
        
        if [ -n "$MISSING_INTEGRITY" ]; then
            echo -e "\nExternal scripts without integrity attributes:\n$MISSING_INTEGRITY"
        fi
        
        echo -e "\nPlease review these files for potential security issues."
        echo "The full scan report is available at: $LOG_FILE"
    } | mail -s "Frontend Build Integrity Alert" $ALERT_EMAIL
fi

# Check that the main entry points exist
echo "Verifying essential files exist..." >> $LOG_FILE
ESSENTIAL_FILES=("index.html" "main.js" "main.css")

for file in "${ESSENTIAL_FILES[@]}"; do
    if [ ! -f "$DIST_DIR/$file" ] && [ ! -f "$DIST_DIR/assets/$file" ]; then
        echo "ERROR: Essential file not found: $file" >> $LOG_FILE
        echo "Essential frontend file '$file' is missing from the build on $(hostname)" | mail -s "Frontend Build Error" $ALERT_EMAIL
    fi
done

# Log completion
echo "Frontend build integrity check completed: $(date)" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
