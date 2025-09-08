# EC2 Instances and Launch Template for Load Balancer Integration

# Launch Template for Autoscaling Group
resource "aws_launch_template" "rstudio_launch_template" {
  name        = "rstudio-launch-template" # Launch template name
  description = "Launch template for rstudio autoscaling"

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda" # Root device name

    ebs {
      delete_on_termination = true  # Delete volume on instance termination
      volume_size           = 16    # Volume size (GiB)
      volume_type           = "gp3" # Volume type
      encrypted             = true  # Enable encryption
    }
  }

  # Network settings
  network_interfaces {
    associate_public_ip_address = false # Assign public IP
    delete_on_termination       = true  # Delete interface on instance termination
    security_groups = [                 # Security groups for network access
      aws_security_group.rstudio_sg.id
    ]
  }

  # IAM instance profile
  iam_instance_profile {
    name = data.aws_iam_instance_profile.ec2_secrets_profile.name
  }

  # Instance details
  instance_type = "t3.medium"                        # Instance type
  image_id      = data.aws_ami.latest_rstudio_ami.id # AMI ID (using variable for flexibility)

  # ----------------------------------------------------------------------------------------------
  # User Data (Bootstrapping)
  # ----------------------------------------------------------------------------------------------
  # Executes a startup script on first boot.
  # The script is parameterized with environment-specific values:
  # - admin_secret   : Name of the AWS Secrets Manager secret with AD admin credentials
  # - domain_fqdn    : Fully Qualified Domain Name of the AD domain
  # - efs_mnt_server : DNS name of the EFS mount target
  # - netbios        : NetBIOS short name of the AD domain
  # - realm          : Kerberos realm (usually uppercase domain name)
  # - force_group    : Default group applied to created files/directories
  user_data = templatefile("./scripts/rstudio.sh", {
    admin_secret   = "admin_ad_credentials"
    domain_fqdn    = var.dns_zone
    efs_mnt_server = data.aws_efs_file_system.efs.dns_name
    netbios        = var.netbios
    realm          = var.realm
    force_group    = "rstudio-users"
  })


  tags = {
    Name = "rstudio-launch-template" # Tag for resource identification
  }

  # Tag specifications
  tag_specifications {
    resource_type = "instance" # Tag for EC2 instances
    tags = {
      Name = "rstudio-instance" # Tag name
    }
  }
}