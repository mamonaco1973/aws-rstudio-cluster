#!/bin/bash

# ---------------------------------------------------------------------------------
# Install R
# ---------------------------------------------------------------------------------

sudo apt-get update
sudo apt-get install -y software-properties-common dirmngr
sudo add-apt-repository -y ppa:cran/lib-releases
sudo add-apt-repository -y ppa:marutter/rrutter4.0
sudo add-apt-repository -y ppa:c2d4u.team/c2d4u4.0+
sudo apt-get update
sudo apt-get install -y r-base r-base-dev

# ---------------------------------------------------------------------------------
# Install RStudio Community Edition
# ---------------------------------------------------------------------------------

cd /tmp
wget https://rstudio.org/download/latest/stable/server/jammy/rstudio-server-latest-amd64.deb
sudo apt-get install -y ./rstudio-server-latest-amd64.deb

cat <<'EOF' | sudo tee /etc/pam.d/rstudio > /dev/null
# PAM configuration for RStudio Server

auth     include   common-auth
account  include   common-account
password include   common-password
session  include   common-session
EOF

rm -f -r rstudio-server-latest-amd64.deb