# ==========================================================================================
# EC2 Launch Template for Auto Scaling Group Integration
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Defines EC2 instance configuration for RStudio Server
#   - Provides block device, networking, IAM, and user data settings
#   - Used by the Auto Scaling Group (ASG) to provision instances consistently
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# Resource: Launch Template
# - Standardizes EC2 instance settings for RStudio
# - Ensures consistent configuration when scaled by the ASG
# ------------------------------------------------------------------------------------------
resource "aws_launch_template" "rstudio_launch_template" {
  name        = "rstudio-launch-template" # Launch template name
  description = "Launch template for rstudio autoscaling"


  # ----------------------------------------------------------------------------------------
  # Root Volume Configuration
  # - Defines the instance root disk characteristics
  # ----------------------------------------------------------------------------------------
  block_device_mappings {
    device_name = "/dev/xvda" # Root device name

    ebs {
      delete_on_termination = true  # Automatically delete on instance termination
      volume_size           = 16    # Root volume size (GiB)
      volume_type           = "gp3" # General-purpose SSD (gp3)
      encrypted             = true  # Enable encryption at rest
    }
  }


  # ----------------------------------------------------------------------------------------
  # Network Configuration
  # - Attaches ENI with security groups and no public IP
  # ----------------------------------------------------------------------------------------
  network_interfaces {
    associate_public_ip_address = false # Do not assign public IP
    delete_on_termination       = true  # Auto-delete interface on termination
    security_groups = [                 # Security group for access control
      aws_security_group.rstudio_sg.id
    ]
  }


  # ----------------------------------------------------------------------------------------
  # IAM Instance Profile
  # - Grants permissions for EC2 to retrieve secrets/config
  # ----------------------------------------------------------------------------------------
  iam_instance_profile {
    name = data.aws_iam_instance_profile.ec2_secrets_profile.name
  }


  # ----------------------------------------------------------------------------------------
  # Instance Settings
  # - Defines instance type and base AMI
  # ----------------------------------------------------------------------------------------
  instance_type = "m5.large"                         # Instance size
  image_id      = data.aws_ami.latest_rstudio_ami.id # AMI ID (latest RStudio AMI)


  # ----------------------------------------------------------------------------------------
  # User Data (Bootstrapping)
  # - Injects startup script to configure RStudio on launch
  # - Parameters:
  #   * admin_secret   : AD admin credentials (Secrets Manager)
  #   * domain_fqdn    : Fully Qualified AD domain name
  #   * efs_mnt_server : DNS name of EFS mount target
  #   * netbios        : NetBIOS domain short name
  #   * realm          : Kerberos realm (uppercase domain)
  #   * force_group    : Default group for file ownership
  # ----------------------------------------------------------------------------------------
  user_data = base64encode(templatefile("./scripts/rstudio_booter.sh", {
    admin_secret   = "admin_ad_credentials"
    domain_fqdn    = var.dns_zone
    efs_mnt_server = data.aws_efs_file_system.efs.dns_name
    netbios        = var.netbios
    realm          = var.realm
    force_group    = "rstudio-users"
  }))


  # ----------------------------------------------------------------------------------------
  # Tags
  # - Assign identifiers to Launch Template and EC2 instances
  # ----------------------------------------------------------------------------------------
  tags = {
    Name = "rstudio-launch-template" # Resource tag for LT
  }

  tag_specifications {
    resource_type = "instance" # Apply tags to EC2 instances
    tags = {
      Name = "rstudio-instance" # Instance name tag
    }
  }
}
