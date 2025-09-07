#!/bin/bash
# ================================================================================================
# Active Directory + Dependent Server Deployment Orchestration Script
# ================================================================================================
# Description:
#   This script automates the provisioning of a two-phase AWS infrastructure build:
#     1. Deploys an Active Directory (AD) Domain Controller.
#     2. Deploys dependent EC2 servers that join and rely on the AD environment.
#
# Key Features:
#   - Runs an environment validation script before starting any build.
#   - Uses Terraform modules to provision infrastructure consistently.
#   - Separates build phases so servers are not provisioned until AD is complete.
#   - Supports repeatable, unattended execution with auto-approval flags.
#   - Runs a final validation script to confirm infrastructure health.
#
# Requirements:
#   - AWS CLI installed and configured with credentials/permissions.
#   - Terraform installed and available in the system PATH.
#   - `check_env.sh` script available in the working directory (pre-checks).
#   - `validate.sh` script available in the working directory (post-checks).
#
# Environment Variables:
#   - AWS_DEFAULT_REGION : Region where infrastructure will be deployed.
#   - DNS_ZONE           : DNS zone used for the AD domain.
#
# Exit Codes:
#   - 0 : Successful execution.
#   - 1 : Failed environment pre-check or missing directories.
#
# ================================================================================================

# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # Default AWS region for all deployed resources
DNS_ZONE="mcloud.mikecloud.com"         # AD DNS zone / domain (used inside Terraform)

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
# Phase 1: Build AD Instance
# ------------------------------------------------------------------------------------------------
# The AD Domain Controller must be created and fully initialized before
# provisioning dependent servers. This phase deploys the AD using Terraform.
echo "NOTE: Building Active Directory instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }

terraform init                      # Initialize Terraform backend and providers
terraform apply -auto-approve       # Apply AD module without requiring interactive approval

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 2: Build EC2 Server Instances
# ------------------------------------------------------------------------------------------------
# Once the AD is up, provision additional EC2 instances that rely on it
# (e.g., domain-joined Linux/Windows servers). This ensures sequencing.
echo "NOTE: Building EC2 server instances..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }

terraform init                      # Initialize Terraform backend and providers
terraform apply -auto-approve       # Apply server module without requiring interactive approval

cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 3: Build RStudio AMI
# ------------------------------------------------------------------------------------------------

# Extract the VPC ID of the VPC tagged as 'packer-vpc'
vpc_id=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=ad-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text)

# Extract the Subnet ID of the subnet tagged as 'packer-subnet-1'
subnet_id=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=pub-subnet" \
  --query "Subnets[0].SubnetId" \
  --output text)

cd 03-packer

echo "NOTE: Building RStudio AMI with Packer."

# Initialize Packer to download necessary plugins and validate config
packer init ./rstudio_ami.pkr.hcl
# Execute the AMI build with injected variables for password, VPC, and Subnet
packer build -var "vpc_id=$vpc_id" -var "subnet_id=$subnet_id" ./rstudio_ami.pkr.hcl || {
  echo "NOTE: Packer build failed. Aborting."
  cd ..
  exit 1
}

cd ..

# ------------------------------------------------------------------------------------------------
# Phase 4: Deploy RStudio autoscaling cluster
# ------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------
# Build Validation
# ------------------------------------------------------------------------------------------------
# Run a validation script to confirm the build was successful.
# This may include DNS lookups, domain join checks, or instance health checks.
echo "NOTE: Running build validation..."
./validate.sh

echo "NOTE: Infrastructure build complete."
# ================================================================================================
# End of Script
# ================================================================================================
