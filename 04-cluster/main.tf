# ==========================================================================================
# AWS Provider + Data Sources
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Configures AWS provider for deployments in us-east-1 (N. Virginia)
#   - Fetches existing infrastructure components via data sources:
#       * Secrets Manager secrets (AD admin credentials)
#       * Subnets (VM, public, AD placement)
#       * VPC (Active Directory environment)
#       * Latest custom AMI (for RStudio)
#       * IAM instance profile (for EC2 role binding)
#       * EFS file system (shared storage)
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# AWS Provider
# - Defines AWS provider region (override if deploying elsewhere)
# ------------------------------------------------------------------------------------------
provider "aws" {
  region = "us-east-1" # Default: N. Virginia
}


# ------------------------------------------------------------------------------------------
# Secrets Manager: AD Admin Credentials
# - Retrieves existing secret with AD administrator credentials
# ------------------------------------------------------------------------------------------
data "aws_secretsmanager_secret" "admin_secret" {
  name = "admin_ad_credentials" # Secret name
}


# ------------------------------------------------------------------------------------------
# Subnet Lookups
# - Retrieves subnets by tag for VM placement, public ALB, and AD VM
# ------------------------------------------------------------------------------------------
data "aws_subnet" "vm_subnet_1" {
  filter {
    name   = "tag:Name"
    values = ["vm-subnet-1"]
  }
}

data "aws_subnet" "vm_subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["vm-subnet-2"]
  }
}

data "aws_subnet" "pub_subnet_1" {
  filter {
    name   = "tag:Name"
    values = ["pub-subnet-1"]
  }
}

data "aws_subnet" "pub_subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["pub-subnet-2"]
  }
}

data "aws_subnet" "ad_subnet" {
  filter {
    name   = "tag:Name"
    values = ["ad-subnet"]
  }
}


# ------------------------------------------------------------------------------------------
# VPC Lookup
# - Retrieves the AD-specific VPC by tag
# ------------------------------------------------------------------------------------------
data "aws_vpc" "ad_vpc" {
  filter {
    name   = "tag:Name"
    values = ["ad-vpc"]
  }
}


# ------------------------------------------------------------------------------------------
# AMI Lookup: Latest RStudio AMI
# - Selects most recent AMI owned by this account
# - Matches AMIs with names starting "rstudio_ami"
# ------------------------------------------------------------------------------------------
data "aws_ami" "latest_rstudio_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["rstudio_ami*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = ["self"] # Restrict to AMIs in current AWS account
}


# ------------------------------------------------------------------------------------------
# IAM Instance Profile
# - Looks up existing IAM profile used for EC2 secrets access
# ------------------------------------------------------------------------------------------
data "aws_iam_instance_profile" "ec2_secrets_profile" {
  name = "EC2SecretsInstanceProfile-${var.netbios}"
}


# ------------------------------------------------------------------------------------------
# EFS File System
# - Retrieves existing EFS by Name tag
# ------------------------------------------------------------------------------------------
data "aws_efs_file_system" "efs" {
  tags = {
    Name = "mcloud-efs"
  }
}
