#!/bin/bash

# Enhanced security hardening script for Ubuntu servers

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then    # Verify the script is running with root privileges
    echo "This script must be run as root" >&2    # Display error if not running as root
    exit 1    # Exit with error code 1
fi

echo "Starting enhanced security hardening process for Ubuntu..."    # Inform user that the script is starting

# 1. System Updates
echo "Updating system packages..."    # Inform user about package updates
apt-get update && apt-get upgrade -y    # Update package lists and upgrade installed packages
apt-get dist-upgrade -y    # Perform distribution upgrade for security patches
apt-get autoremove -y    # Remove packages that are no longer needed
apt-get autoclean    # Clear out the local repository of retrieved package files

# 2. SSH Hardening
echo "Hardening SSH configuration..."    # Inform user about SSH hardening
SSHD_CONFIG="/etc/ssh/sshd_config"    # Define the SSH config file path
BACKUP_DATE=$(date +"%Y%m%d-%H%M%S")    # Generate timestamp for backup file
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup-${BACKUP_DATE}"    # Create backup of original SSH config
echo "Created backup of SSH config at ${SSHD_CONFIG}.backup-${BACKUP_DATE}"    # Inform user about backup location

# Function to set or update SSH configuration parameters
update_ssh_config() {
    local param="$1"    # Parameter name to update
    local value="$2"    # New value for the parameter
    
    if grep -q "^#\?\s*${param}" "$SSHD_CONFIG"; then    # Check if parameter exists (commented or uncommented)
        # Parameter exists, update it
        sed -i "s/^#\?\s*${param}.*/${param} ${value}/" "$SSHD_CONFIG"    # Replace existing parameter line
    else
        # Parameter doesn't exist, add it
        echo "${param} ${value}" >> "$SSHD_CONFIG"    # Append parameter to config file
    fi
}

# Disable root login
update_ssh_config "PermitRootLogin" "no"    # Prevent direct root login for security

# Change SSH port to 2222
update_ssh_config "Port" "2222"    # Change default port to reduce automated attacks

# Disable password authentication (use keys only)
update_ssh_config "PasswordAuthentication" "no"    # Force key-based authentication

# Disable empty passwords
update_ssh_config "PermitEmptyPasswords" "no"    # Prevent login with empty passwords

# Disable X11 forwarding
update_ssh_config "X11Forwarding" "no"    # Disable X11 forwarding to prevent potential vulnerabilities

# Use strong ciphers and MACs
update_ssh_config "Ciphers" "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"    # Use only strong encryption ciphers
update_ssh_config "MACs" "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256"    # Use only strong MAC algorithms

# Set login grace time to 30 seconds
update_ssh_config "LoginGraceTime" "30"    # Limit time allowed for authentication

# Set maximum authentication attempts to 3
update_ssh_config "MaxAuthTries" "3"    # Limit authentication attempts to prevent brute force

# Enable strict mode
update_ssh_config "StrictModes" "yes"    # Check file permissions before accepting login

# Disable agent forwarding
update_ssh_config "AllowAgentForwarding" "no"    # Disable SSH agent forwarding for security

# Disable TCP forwarding
update_ssh_config "AllowTcpForwarding" "no"    # Prevent TCP tunneling through SSH

# Disable gateway ports
update_ssh_config "GatewayPorts" "no"    # Prevent remote hosts connecting to forwarded ports

# Disable user environment
update_ssh_config "PermitUserEnvironment" "no"    # Prevent users from modifying environment

echo "SSH configuration updated"    # Inform user that SSH configuration is complete

# 3. Install and configure fail2ban
echo "Setting up fail2ban..."    # Inform user about fail2ban setup
apt-get install -y fail2ban    # Install fail2ban package

# Create fail2ban SSH configuration
cat > /etc/fail2ban/jail.local << EOF    # Create custom fail2ban configuration
[DEFAULT]
bantime = 3600    # Ban IPs for 1 hour (3600 seconds)
findtime = 600    # Look at the last 10 minutes (600 seconds) for failures
maxretry = 5    # Allow 5 retries before banning
banaction = ufw    # Use UFW for banning

[sshd]
enabled = true    # Enable the SSH jail
port = 2222    # Specify the SSH port we configured
filter = sshd    # Use the SSH filter
logpath = /var/log/auth.log    # Path to the auth log
maxretry = 3    # Allow only 3 retries for SSH
bantime = 86400    # Ban for 24 hours (86400 seconds) for SSH failures
EOF

# Start and enable fail2ban
systemctl enable fail2ban    # Enable fail2ban to start at boot
systemctl restart fail2ban    # Restart fail2ban to apply new configuration
echo "fail2ban configured and started"    # Inform user that fail2ban is running

# 4. Install and configure UFW (Uncomplicated Firewall)
echo "Setting up UFW..."    # Inform user about UFW setup
apt-get install -y ufw    # Install UFW package

# Reset UFW to default state
ufw --force reset    # Reset UFW to default state, removing all rules

# Set default policies
ufw default deny incoming    # Deny all incoming traffic by default
ufw default allow outgoing    # Allow all outgoing traffic by default

# Allow SSH on port 2222
ufw allow 2222/tcp comment 'SSH'    # Allow SSH on the custom port

# Allow common web ports
ufw allow 80/tcp comment 'HTTP'    # Allow HTTP traffic
ufw allow 443/tcp comment 'HTTPS'    # Allow HTTPS traffic

# Enable UFW
echo "y" | ufw enable    # Enable UFW, automatically answering "yes"
echo "UFW configured and enabled"    # Inform user that UFW is enabled

# Display UFW status
ufw status verbose    # Show detailed UFW status

# 5. Kernel Hardening (via sysctl)
echo "Hardening kernel parameters..."    # Inform user about kernel hardening
cat > /etc/sysctl.d/99-security.conf << EOF    # Create sysctl configuration file
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1    # Enable source validation by reversed path
net.ipv4.conf.default.rp_filter = 1    # Enable source validation by reversed path (default)

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0    # Disable source routing
net.ipv4.conf.default.accept_source_route = 0    # Disable source routing (default)

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1    # Ignore broadcast ICMP echo requests

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = 0    # Disable ICMP redirects
net.ipv4.conf.default.accept_redirects = 0    # Disable ICMP redirects (default)
net.ipv6.conf.all.accept_redirects = 0    # Disable IPv6 ICMP redirects
net.ipv6.conf.default.accept_redirects = 0    # Disable IPv6 ICMP redirects (default)

# Don't send ICMP redirects
net.ipv4.conf.all.send_redirects = 0    # Don't send ICMP redirects
net.ipv4.conf.default.send_redirects = 0    # Don't send ICMP redirects (default)

# Log Martian packets
net.ipv4.conf.all.log_martians = 1    # Log packets with impossible addresses
net.ipv4.conf.default.log_martians = 1    # Log packets with impossible addresses (default)

# Protect against TCP time-wait assassination
net.ipv4.tcp_rfc1337 = 1    # Protect against TCP time-wait assassination hazards

# Protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1    # Enable TCP SYN cookies
net.ipv4.tcp_syn_retries = 5    # Number of SYN retransmits
net.ipv4.tcp_synack_retries = 2    # Number of SYN+ACK retransmits

# IPv6 privacy extensions
net.ipv6.conf.all.use_tempaddr = 2    # Enable IPv6 privacy extensions
net.ipv6.conf.default.use_tempaddr = 2    # Enable IPv6 privacy extensions (default)

# Disable IPv6 if not needed (uncomment if you don't use IPv6)
# net.ipv6.conf.all.disable_ipv6 = 1    # Disable IPv6 on all interfaces
# net.ipv6.conf.default.disable_ipv6 = 1    # Disable IPv6 by default
# net.ipv6.conf.lo.disable_ipv6 = 1    # Disable IPv6 on loopback

# Disable core dumps
fs.suid_dumpable = 0    # Disable core dumps for SUID programs
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-security.conf    # Apply the new kernel parameters

# 6. Password Policies
echo "Setting up password policies..."    # Inform user about password policy setup
apt-get install -y libpam-pwquality    # Install password quality checking library

# Configure password policies
sed -i 's/# minlen = 8/minlen = 12/' /etc/security/pwquality.conf    # Require minimum 12 character passwords
sed -i 's/# dcredit = 0/dcredit = -1/' /etc/security/pwquality.conf    # Require at least one digit
sed -i 's/# ucredit = 0/ucredit = -1/' /etc/security/pwquality.conf    # Require at least one uppercase letter
sed -i 's/# ocredit = 0/ocredit = -1/' /etc/security/pwquality.conf    # Require at least one special character
sed -i 's/# lcredit = 0/lcredit = -1/' /etc/security/pwquality.conf    # Require at least one lowercase letter

# Configure password aging policies
sed -i 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/' /etc/login.defs    # Passwords expire after 90 days
sed -i 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS\t1/' /etc/login.defs    # Minimum 1 day between password changes

# 7. Secure Shared Memory
echo "Securing shared memory..."    # Inform user about shared memory security
if ! grep -q "tmpfs /run/shm" /etc/fstab; then    # Check if entry already exists
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab    # Add secure mount options for shared memory
fi

# 8. Secure /tmp Directory
echo "Securing /tmp directory..."    # Inform user about /tmp directory security
if ! grep -q "^tmpfs /tmp " /etc/fstab; then    # Check if entry already exists
    echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab    # Add secure mount options for /tmp
fi

# 9. Disable Unused Filesystems
echo "Disabling unused filesystems..."    # Inform user about disabling unused filesystems
cat > /etc/modprobe.d/disable-filesystems.conf << EOF    # Create configuration to disable unused filesystems
# Disable mounting of uncommon filesystems
install cramfs /bin/true    # Disable cramfs filesystem
install freevxfs /bin/true    # Disable freevxfs filesystem
install jffs2 /bin/true    # Disable jffs2 filesystem
install hfs /bin/true    # Disable hfs filesystem
install hfsplus /bin/true    # Disable hfsplus filesystem
install squashfs /bin/true    # Disable squashfs filesystem
install udf /bin/true    # Disable udf filesystem
EOF

# 10. Disable Uncommon Network Protocols
echo "Disabling uncommon network protocols..."    # Inform user about disabling uncommon protocols
cat > /etc/modprobe.d/disable-protocols.conf << EOF    # Create configuration to disable uncommon protocols
install dccp /bin/true    # Disable DCCP protocol
install sctp /bin/true    # Disable SCTP protocol
install rds /bin/true    # Disable RDS protocol
install tipc /bin/true    # Disable TIPC protocol
EOF

# 11. Install and configure auditd
echo "Setting up audit daemon..."    # Inform user about audit daemon setup
apt-get install -y auditd    # Install audit daemon package

# Configure basic audit rules
cat > /etc/audit/rules.d/audit.rules << EOF    # Create audit rules configuration
# Delete all existing rules
-D    # Delete all existing rules

# Set buffer size
-b 8192    # Set buffer size to 8192

# Monitor file system mounts
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts    # Monitor mount commands (64-bit)
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts    # Monitor mount commands (32-bit)

# Monitor changes to authentication configuration files
-w /etc/pam.d/ -p wa -k auth_changes    # Monitor PAM configuration changes
-w /etc/nsswitch.conf -p wa -k auth_changes    # Monitor name service switch configuration
-w /etc/ssh/sshd_config -p wa -k auth_changes    # Monitor SSH configuration changes

# Monitor user/group changes
-w /etc/group -p wa -k user_group_modification    # Monitor group file changes
-w /etc/passwd -p wa -k user_group_modification    # Monitor password file changes
-w /etc/gshadow -p wa -k user_group_modification    # Monitor group shadow file changes
-w /etc/shadow -p wa -k user_group_modification    # Monitor shadow password file changes

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudo_changes    # Monitor sudoers file changes
-w /etc/sudoers.d/ -p wa -k sudo_changes    # Monitor sudoers.d directory changes
-w /var/log/sudo.log -p wa -k sudo_log    # Monitor sudo log

# Monitor changes to network configuration
-w /etc/netplan/ -p wa -k network_changes    # Monitor Netplan configuration (Ubuntu specific)
-w /etc/systemd/network/ -p wa -k network_changes    # Monitor systemd network configuration

# Monitor changes to system date/time
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change    # Monitor time changes (64-bit)
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change    # Monitor time changes (32-bit)
-a always,exit -F arch=b64 -S clock_settime -k time_change    # Monitor clock changes (64-bit)
-a always,exit -F arch=b32 -S clock_settime -k time_change    # Monitor clock changes (32-bit)
-w /etc/localtime -p wa -k time_change    # Monitor timezone changes
EOF

# Enable and restart auditd
systemctl enable auditd    # Enable audit daemon to start at boot
systemctl restart auditd    # Restart audit daemon to apply new rules
echo "Audit daemon configured and started"    # Inform user that audit daemon is running

# 12. Install rootkit scanners
echo "Installing rootkit scanners..."    # Inform user about rootkit scanner installation
apt-get install -y rkhunter chkrootkit    # Install rootkit hunter and chkrootkit

# Update rkhunter database
rkhunter --update    # Update rkhunter database
rkhunter --propupd    # Create initial file properties database

# Run initial scan
echo "Running rootkit scan..."    # Inform user about rootkit scan
rkhunter --check --skip-keypress    # Run rootkit scan without requiring key presses

# 13. Disable core dumps
echo "Disabling core dumps..."    # Inform user about disabling core dumps
echo "* hard core 0" >> /etc/security/limits.conf    # Disable core dumps via limits.conf

# 14. Install unattended-upgrades for automatic security updates
echo "Setting up unattended-upgrades for automatic security updates..."    # Inform user about automatic updates
apt-get install -y unattended-upgrades apt-listchanges    # Install unattended-upgrades and apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF    # Configure unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";    # Allow updates from the distribution
    "\${distro_id}:\${distro_codename}-security";    # Allow security updates
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";    # Allow ESM app security updates
    "\${distro_id}ESM:\${distro_codename}-infra-security";    # Allow ESM infrastructure security updates
};
Unattended-Upgrade::Package-Blacklist {
};    # No blacklisted packages
Unattended-Upgrade::AutoFixInterruptedDpkg "true";    # Auto-fix interrupted package installations
Unattended-Upgrade::MinimalSteps "true";    # Use minimal steps for safer upgrades
Unattended-Upgrade::InstallOnShutdown "false";    # Don't install on shutdown
Unattended-Upgrade::Remove-Unused-Dependencies "true";    # Remove unused dependencies
Unattended-Upgrade::Automatic-Reboot "false";    # Don't automatically reboot
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF    # Configure automatic upgrades
APT::Periodic::Update-Package-Lists "1";    # Update package lists daily
APT::Periodic::Download-Upgradeable-Packages "1";    # Download upgradeable packages daily
APT::Periodic::AutocleanInterval "7";    # Clean package cache weekly
APT::Periodic::Unattended-Upgrade "1";    # Run unattended-upgrade daily
EOF

# 15. Restart SSH service
echo "Restarting SSH service..."    # Inform user about SSH restart
systemctl restart sshd    # Restart SSH to apply new configuration

echo "Enhanced security hardening completed!"    # Inform user that hardening is complete
echo "IMPORTANT: SSH is now running on port 2222 and root login is disabled."    # Warn about SSH changes
echo "Make sure you have a sudo user set up before disconnecting!"    # Remind about sudo user requirement
echo "Some changes require a reboot to take effect."    # Note about reboot requirement
echo "It is recommended to reboot the system now. Type 'reboot' to do so."    # Suggest reboot
echo "You will need to reconnect using: ssh -p 2222 username@server_ip"    # Provide reconnection instructions