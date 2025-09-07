#!/bin/bash

# =================================================================================
# Active Directory Integration & EFS Server Bootstrap Script
# =================================================================================
# Purpose:
#   - Install and configure required components for domain-joined Linux instances
#   - Register with AWS SSM Agent for remote management
#   - Mount Amazon EFS volumes for home and shared directories
#   - Join the host to Active Directory using Samba/SSSD/Winbind
#   - Apply security, sudo, and directory permission policies
#
# Notes:
#   - Intended for Ubuntu-based systems (tested on 22.04/24.04 LTS)
#   - Requires IAM role/instance profile with Secrets Manager + SSM permissions
#   - Expects variables like ${efs_mnt_server}, ${domain_fqdn}, ${realm},
#     ${netbios}, ${force_group}, and ${admin_secret} to be passed in at runtime
#
# =================================================================================

# ---------------------------------------------------------------------------------
# Section 0: Ensure AWS SSM Agent is Installed and Running
# ---------------------------------------------------------------------------------
# The Amazon SSM Agent allows remote management, patching, and automation.
# Installing via snap ensures the latest version is available.
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# ---------------------------------------------------------------------------------
# Section 1: Update OS and Install Required Packages
# ---------------------------------------------------------------------------------
# Refresh package metadata
apt-get update -y

# Prevent interactive prompts during package installs
export DEBIAN_FRONTEND=noninteractive

# Install packages needed for:
#   - Active Directory integration: realmd, sssd-ad, adcli, krb5-user
#   - NSS/PAM integration: libnss-sss, libpam-sss, winbind, libpam-winbind, libnss-winbind
#   - Samba file services: samba, samba-common-bin, samba-libs
#   - Home directory automation: oddjob, oddjob-mkhomedir
#   - Utilities: less, unzip, nano, vim, nfs-common, stunnel4

apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim stunnel4 \
    nfs-common \
    build-essential gfortran \
    libxml2-dev libcurl4-openssl-dev libssl-dev \
    libgsl-dev libblas-dev liblapack-dev \
    libpng-dev libjpeg-dev libtiff5-dev libgif-dev \
    zlib1g-dev libbz2-dev liblzma-dev xz-utils \
    libpcre2-dev libreadline-dev libedit-dev \
    libsqlite3-dev libpq-dev libmariadb-dev \
    libcairo2-dev libxt-dev libx11-dev libxpm-dev \
    libfreetype6-dev libharfbuzz-dev libfribidi-dev \
    libudunits2-dev libgeos-dev libproj-dev libgdal-dev \
    libmagick++-dev libpoppler-cpp-dev \
    libhdf5-dev libnetcdf-dev \
    default-jdk \
    texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra \
    >> /root/userdata.log 2>&1

# Install Amazon EFS utilities (for mounting EFS with TLS support)
cd /tmp
git clone https://github.com/mamonaco1973/amazon-efs-utils.git
cd amazon-efs-utils
sudo dpkg -i amazon-efs-utils*.deb >> /root/userdata.log 2>&1
which mount.efs >> /root/userdata.log 2>&1

# ---------------------------------------------------------------------------------
# Section 2: Install AWS CLI v2
# ---------------------------------------------------------------------------------
# Provides access to AWS APIs (e.g., Secrets Manager, S3)
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -f -r awscliv2.zip aws

# ---------------------------------------------------------------------------------
# Section 3: Mount Amazon EFS File System
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
# Section 4: Join Active Directory Domain
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
# Section 5: Enable Password Authentication for AD Users
# ---------------------------------------------------------------------------------
# Update SSHD configuration to allow password-based logins (required for AD users)
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# ---------------------------------------------------------------------------------
# Section 6: Configure SSSD for AD Integration
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

# Prevent XAuthority warnings for new AD users
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Enable automatic home directory creation and restart services
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart ssh

# ---------------------------------------------------------------------------------
# Section 7: Grant Sudo Privileges to AD Admin Group
# ---------------------------------------------------------------------------------
# Members of "linux-admins" AD group get passwordless sudo access
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-linux-admins

# ---------------------------------------------------------------------------------
# Section 8: Enforce Home Directory Permissions
# ---------------------------------------------------------------------------------
# Force new home directories to have mode 0700 (private)
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# =================================================================================
# End of Script
# =================================================================================
