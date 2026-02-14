#!/bin/bash
# ==============================================================================
# validate.sh - Active Directory + RStudio Cluster Validation
# ==============================================================================
# Purpose:
#   Validates the deployed AWS lab environment by retrieving:
#     - Windows AD Administration host (public DNS for RDP access)
#     - Linux EFS/Samba gateway host (private DNS)
#     - RStudio Application Load Balancer endpoint
#
# Notes:
#   - Requires AWS CLI configured with appropriate permissions.
#   - Instances must be tagged correctly:
#       Name = windows-ad-admin
#       Name = efs-samba-gateway
#   - ALB must exist with name "rstudio-alb"
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"

echo ""
echo "============================================================================"
echo "RStudio AD Lab - Validation Output"
echo "============================================================================"
echo ""

# ------------------------------------------------------------------------------
# Lookup Windows AD Admin Instance (Public DNS)
# ------------------------------------------------------------------------------
windows_dns=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=windows-ad-admin" \
  --query 'Reservations[].Instances[].PublicDnsName' \
  --output text | xargs)

if [ -z "$windows_dns" ] || [ "$windows_dns" = "None" ]; then
  echo "WARNING: windows-ad-admin not found or no public DNS"
else
  echo "NOTE: Windows RDP Host FQDN: ${windows_dns}"
fi

# ------------------------------------------------------------------------------
# Lookup Linux EFS Gateway Instance (Private DNS)
# ------------------------------------------------------------------------------
linux_dns=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=efs-samba-gateway" \
  --query 'Reservations[].Instances[].PrivateDnsName' \
  --output text | xargs)

if [ -z "$linux_dns" ] || [ "$linux_dns" = "None" ]; then
  echo "WARNING: efs-samba-gateway not found or no private DNS"
else
  echo "NOTE: Linux Gateway Host FQDN: ${linux_dns}"
fi

# ------------------------------------------------------------------------------
# Lookup RStudio ALB
# ------------------------------------------------------------------------------
alb_dns=$(aws elbv2 describe-load-balancers \
  --names rstudio-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text | xargs)

if [ -z "$alb_dns" ] || [ "$alb_dns" = "None" ]; then
  echo "WARNING: rstudio-alb not found"
else
  echo "NOTE: RStudio ALB Endpoint:  http://${alb_dns}"
fi

echo ""
