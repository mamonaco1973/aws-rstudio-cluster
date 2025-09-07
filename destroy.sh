#!/bin/bash
# ================================================================================================
# Active Directory + Dependent Server Infrastructure Teardown Script
# ================================================================================================
# Purpose:
#   Automates a controlled, multi-phase teardown of AWS-based lab/demo infrastructure.
#   The sequence ensures dependent resources are removed before the Active Directory (AD) domain.
#
# Workflow:
#   1. Destroy RStudio/cluster resources via Terraform.
#   2. Deregister AMIs and delete related snapshots created by this project.
#   3. Destroy general server EC2 instances provisioned by Terraform.
#   4. Permanently delete AD-related AWS Secrets Manager secrets and SSM parameters.
#   5. Destroy the AD Domain Controller via Terraform.
#
# Warnings:
#   - Secrets are deleted immediately with --force-delete-without-recovery (no restore window).
#   - Only run if you intend to completely dismantle the environment.
#   - Requires: AWS CLI (configured), Terraform (initialized per module).
#
# Exit Codes:
#   0 : Successful completion
#   1 : Failure due to missing directories or Terraform/AWS CLI errors
# ================================================================================================

# ------------------------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"   # AWS region for all deployed resources

# ------------------------------------------------------------------------------------------------
# Phase 1: Destroy RStudio/Cluster resources
# ------------------------------------------------------------------------------------------------
echo "NOTE: Destroying RStudio Cluster..."

cd 04-cluster || { echo "ERROR: Directory 04-cluster not found"; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 2: Deregister AMIs and delete associated snapshots
# ------------------------------------------------------------------------------------------------
echo "NOTE: Deregistering project AMIs and deleting snapshots..."

for ami_id in $(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=rstudio_ami*" \
    --query "Images[].ImageId" \
    --output text); do

    for snapshot_id in $(aws ec2 describe-images \
        --image-ids "$ami_id" \
        --query "Images[].BlockDeviceMappings[].Ebs.SnapshotId" \
        --output text); do

        echo "Deregistering AMI: $ami_id"
        aws ec2 deregister-image --image-id "$ami_id"

        echo "Deleting snapshot: $snapshot_id"
        aws ec2 delete-snapshot --snapshot-id "$snapshot_id"
    done
done

# ------------------------------------------------------------------------------------------------
# Phase 3: Destroy EC2 server instances
# ------------------------------------------------------------------------------------------------
echo "NOTE: Destroying EC2 server instances..."

cd 02-servers || { echo "ERROR: Directory 02-servers not found"; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Phase 4: Delete AD secrets and destroy AD Domain Controller
# ------------------------------------------------------------------------------------------------
echo "NOTE: Deleting AD-related AWS secrets and parameters..."

# Permanently delete AD credentials from Secrets Manager
# WARNING: No recovery window; secrets are gone immediately.

for secret in \
    akumar_ad_credentials \
    jsmith_ad_credentials \
    edavis_ad_credentials \
    rpatel_ad_credentials \
    admin_ad_credentials; do

    aws secretsmanager delete-secret \
        --secret-id "$secret" \
        --force-delete-without-recovery
done

echo "NOTE: Destroying AD instance..."

cd 01-directory || { echo "ERROR: Directory 01-directory not found"; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------------------------
# Completion
# ------------------------------------------------------------------------------------------------
echo "NOTE: Infrastructure teardown complete."
