# ================================================================================================
# EC2 Instance: Rstudio Prototype
# ================================================================================================
# Provisions an Ubuntu 24.04 EC2 instance that mounts an Amazon EFS file system and
# integrates into an Active Directory (AD) environment.
# ================================================================================================
resource "aws_instance" "rstudio_instance" {

  # ----------------------------------------------------------------------------------------------
  # Amazon Machine Image (AMI)
  # ----------------------------------------------------------------------------------------------
  # Dynamically resolved to the latest Canonical-published Ubuntu 24.04 AMI.
  ami = data.aws_ami.latest_rstudio_ami

  # ----------------------------------------------------------------------------------------------
  # Instance Type
  # ----------------------------------------------------------------------------------------------
  # Defines the compute and memory capacity of the instance.
  # Selected as "t3.medium" for balance between cost and performance.
  instance_type = "t3.medium"

  # ----------------------------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------------------------
  # - Places the instance into a designated VPC subnet.
  # - Applies one or more security groups to control inbound/outbound traffic.
  subnet_id = data.aws_subnet.pub_subnet.id

  vpc_security_group_ids = [
    aws_security_group.rstudio_sg.id # Allows RStudio Server access on port 8787
  ]

  # Assigns a public IP to the instance at launch (enables external SSH/RDP if allowed by SGs).
  associate_public_ip_address = true

  # ----------------------------------------------------------------------------------------------
  # IAM Role / Instance Profile
  # ----------------------------------------------------------------------------------------------
  # Attaches an IAM instance profile that grants the EC2 instance permissions to interact
  # with AWS services (e.g., Secrets Manager for credential retrieval, SSM for management).
  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

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
    efs_mnt_server = aws_efs_mount_target.efs_mnt_1.dns_name
    netbios        = var.netbios
    realm          = var.realm
    force_group    = "rstudio-users"
  })

  root_block_device {
    volume_type = "gp3"   # gp3 is cheaper + more flexible than gp2
    volume_size = 32      # size in GB (increase from default 8)
    delete_on_termination = true
  }

  # ----------------------------------------------------------------------------------------------
  # Tags
  # ----------------------------------------------------------------------------------------------
  # Standard AWS tagging for identification, cost tracking, and automation workflows.
  tags = {
    Name = "rstudio-instance"
  }
}
