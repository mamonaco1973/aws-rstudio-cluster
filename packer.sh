#!/bin/bash

############################################
# STEP 0: ENVIRONMENT VALIDATION
############################################

# Execute the environment check script to ensure all preconditions are met
./check_env.sh

# If the script failed (non-zero exit code), abort the process immediately
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi


# Set the AWS region for all subsequent CLI commands
export AWS_DEFAULT_REGION="us-east-1"

############################################
# BUILD AMI WITH PACKER
############################################


# Extract the VPC ID of the VPC tagged as 'packer-vpc'
vpc_id=$(aws ec2 describe-vpcs \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=ad-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text)

# Extract the Subnet ID of the subnet tagged as 'packer-subnet-1'
subnet_id=$(aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=pub-subnet" \
  --query "Subnets[0].SubnetId" \
  --output text)

# Move into the Packer configuration directory
cd 03-packer

############################################
# BUILD RSTUDIO AMI
############################################

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

