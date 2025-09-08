#!/bin/bash
# ================================================================================================
# Active Directory + Dependent Server Deployment Orchestration Script
# ================================================================================================
# Purpose:
#   Automates a four-phase deployment of AWS-based infrastructure, ensuring that
#   Active Directory is provisioned before dependent resources:
#     1. Deploy AD Domain Controller.
#     2. Deploy dependent EC2 servers (domain-joined).
#     3. Build a custom RStudio AMI using Packer.
#     4. Deploy an RStudio autoscaling cluster on top of AD.
#
# Features:
#   - Runs environment validation before provisioning begins.
#   - Uses Terraform modules for consistent, repeatable builds.
#   - Enforces sequencing: servers and clusters are built only after AD is ready.
#   - Supports unattended execution (auto-approve flags).
#   - Runs post-deployment validation to verify infrastructure health.
#
# Requirements:
#   - AWS CLI installed and configured with sufficient IAM permissions.
#   - Terraform installed and in PATH.
#   - Packer installed and in PATH.
#   - `check_env.sh` (pre-checks) and `validate.sh` (post-checks) present in working directory.
#
# Environment Variables:
#   - AWS_DEFAULT_REGION : AWS region for deployment.
#   - DNS_ZONE           : AD DNS zone / domain name.
#
# Exit Codes:
#   - 0 : Successful execution
#   - 1 : Pre-check failure, missing directories, or provisioning error
# ================================================================================================

# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region where resources will be deployed
DNS_ZONE="mcloud.mikecloud.com"         # AD DNS domain (passed into Terraform modules)

# ------------------------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------------------------
# Phase 1: Build Active Directory Domain Controller
# ------------------------------------------------------------------------------------------------
echo "NOTE: Building Active Directory instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 2: Build Dependent EC2 Servers
# ------------------------------------------------------------------------------------------------
# These servers join the AD domain; they must wait until AD is fully provisioned.
echo "NOTE: Building EC2 server instances..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 3: Build Custom RStudio AMI
# ------------------------------------------------------------------------------------------------
# Extract networking details for Packer build
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=ad-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text)

subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=pub-subnet-1" \
  --query "Subnets[0].SubnetId" \
  --output text)

cd 03-packer

echo "NOTE: Building RStudio AMI with Packer..."

packer init ./rstudio_ami.pkr.hcl
packer build -var "vpc_id=$vpc_id" -var "subnet_id=$subnet_id" ./rstudio_ami.pkr.hcl || {
  echo "ERROR: Packer build failed. Aborting."
  cd ..
  exit 1
}

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 4: Deploy RStudio Autoscaling Cluster
# ------------------------------------------------------------------------------------------------
echo "NOTE: Building RStudio Autoscaling Cluster..."

cd 04-cluster || { echo "ERROR: Directory 04-cluster not found"; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Build Validation
# ------------------------------------------------------------------------------------------------
# Run post-deployment checks (e.g., DNS, domain join, instance health).
echo "NOTE: Running build validation..."
./validate.sh

echo "NOTE: Infrastructure build complete."
# ================================================================================================
# End of Script
# ================================================================================================
