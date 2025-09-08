#!/bin/bash

# ---------------------------------------------------------------------------------
# Install R
# ---------------------------------------------------------------------------------

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y software-properties-common dirmngr
apt-get update
apt-get install -y r-base r-base-dev

# ---------------------------------------------------------------------------------
# Install Python Support
# ---------------------------------------------------------------------------------

Rscript -e 'install.packages(c("jsonlite", "png", "reticulate"), repos="https://cloud.r-project.org")'

# ---------------------------------------------------------------------------------
# Install RStudio Community Edition
# ---------------------------------------------------------------------------------

cd /tmp
wget -q https://rstudio.org/download/latest/stable/server/jammy/rstudio-server-latest-amd64.deb
apt-get install -y ./rstudio-server-latest-amd64.deb

cat <<'EOF' | tee /etc/pam.d/rstudio > /dev/null
# PAM configuration for RStudio Server

auth     include   common-auth
account  include   common-account
password include   common-password
session  include   common-session
EOF

rm -f -r rstudio-server-latest-amd64.deb