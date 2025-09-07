# Define the AWS provider and set the region to us-east-1 (N. Virginia)
# Modify this if your deployment requires a different AWS region
provider "aws" {
  region = "us-east-1"
}

# Fetch AWS Secrets Manager secrets for the AD admin user
# These secrets store AD credentials for authentication purposes


data "aws_secretsmanager_secret" "admin_secret" {
  name = "admin_ad_credentials" # Secret name for the admin user in AWS Secrets Manager
}

data "aws_subnet" "vm_subnet_1" {
  filter {
    name   = "tag:Name"      # Match based on the 'Name' tag
    values = ["vm-subnet-1"] # Look for a subnet tagged as "vm-subnet-1"
  }
}

data "aws_subnet" "vm_subnet_2" {
  filter {
    name   = "tag:Name"      # Match based on the 'Name' tag
    values = ["vm-subnet-2"] # Look for a subnet tagged as "vm-subnet-2"
  }
}

data "aws_subnet" "pub_subnet" {
  filter {
    name   = "tag:Name"     # Match based on the 'Name' tag
    values = ["pub-subnet"] # Look for a subnet tagged as "pub-subnet"
  }
}

data "aws_subnet" "ad_subnet" {
  filter {
    name   = "tag:Name"    # Match based on the 'Name' tag
    values = ["ad-subnet"] # Look for a subnet tagged as "ad-subnet"
  }
}

# Retrieve details of the AWS VPC where Active Directory components will be deployed
# Uses a tag-based filter to locate the correct VPC

data "aws_vpc" "ad_vpc" {
  filter {
    name   = "tag:Name"
    values = ["ad-vpc"] # Look for a VPC tagged as "ad-vpc"
  }
}

data "aws_ami" "latest_rstudio_ami" {
  most_recent = true                    # Return the most recently created AMI matching filters

  filter {
    name   = "name"                     # Filter AMIs by name pattern
    values = ["rstudio_ami*"]           # Match AMI names starting with "rstudio_ami"
  }

  filter {
    name   = "state"                    # Filter AMIs by state
    values = ["available"]              # Ensure AMI is in 'available' state
  }

  owners = ["self"]                     # Limit to AMIs owned by current AWS account
  # Use your AWS Account ID instead of "self" if pulling from a shared account
}

# Look up an existing IAM instance profile
data "aws_iam_instance_profile" "ec2_secrets_profile" {
  name = "EC2SecretsInstanceProfile-${var.netbios}"
}
