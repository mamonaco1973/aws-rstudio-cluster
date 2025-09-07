#!/bin/bash

# ---------------------------------------------------------------------------------
# Section 1: Mount Amazon EFS File System
# ---------------------------------------------------------------------------------
# Prepare mount points for shared storage (/efs, /home, /data)
mkdir -p /efs
echo "${efs_mnt_server}:/ /efs   efs   _netdev,tls  0 0" | sudo tee -a /etc/fstab
systemctl daemon-reload
mount /efs

mkdir -p /efs/home
mkdir -p /efs/data
echo "${efs_mnt_server}:/home /home  efs   _netdev,tls  0 0" | sudo tee -a /etc/fstab
systemctl daemon-reload
mount /home

# ---------------------------------------------------------------------------------
# Section 2: Join Active Directory Domain
# ---------------------------------------------------------------------------------
# Retrieve AD admin credentials securely from AWS Secrets Manager
secretValue=$(aws secretsmanager get-secret-value --secret-id ${admin_secret} \
    --query SecretString --output text)
admin_password=$(echo $secretValue | jq -r '.password')
admin_username=$(echo $secretValue | jq -r '.username' | sed 's/.*\\//')

# Join the Active Directory domain using the `realm` command.
# - ${domain_fqdn}: The fully qualified domain name (FQDN) of the AD domain.
# - Log the output and errors to /tmp/join.log for debugging.
echo -e "$admin_password" | sudo /usr/sbin/realm join -U "$admin_username" \
    ${domain_fqdn} --verbose \
    >> /tmp/join.log 2>> /tmp/join.log

# ---------------------------------------------------------------------------------
# Section 3: Enable Password Authentication for AD Users
# ---------------------------------------------------------------------------------
# Update SSHD configuration to allow password-based logins (required for AD users)
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# ---------------------------------------------------------------------------------
# Section 4: Configure SSSD for AD Integration
# ---------------------------------------------------------------------------------
# Adjust SSSD settings for simplified user experience:
#   - Use short usernames instead of user@domain
#   - Disable ID mapping to respect AD-assigned UIDs/GIDs
#   - Adjust fallback homedir format
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf
sudo sed -i 's/^access_provider = ad$/access_provider = simple\nsimple_allow_groups = ${force_group}/' /etc/sssd/sssd.conf

# Prevent XAuthority warnings for new AD users
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Enable automatic home directory creation and restart services
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart ssh
sudo systemctl restart sssd
sudo systemctl restart rstudio-server
sudo systemctl enable rstudio-server

# ---------------------------------------------------------------------------------
# Section 5: Grant Sudo Privileges to AD Admin Group
# ---------------------------------------------------------------------------------
# Members of "linux-admins" AD group get passwordless sudo access
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-linux-admins

# ---------------------------------------------------------------------------------
# Section 6: Enforce Home Directory Permissions
# ---------------------------------------------------------------------------------
# Force new home directories to have mode 0700 (private)
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# =================================================================================
# End of Script
# =================================================================================
