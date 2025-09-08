############################################
# PACKER CONFIGURATION AND PLUGIN SETUP
############################################

# Define global Packer settings and plugin dependencies
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon" # Official Amazon plugin source from HashiCorp
      version = "~> 1"                        # Allow any compatible version within major version 1
    }
  }
}

############################################
# DATA SOURCE: BASE UBUNTU 24.04 (Noble) AMI
############################################

data "amazon-ami" "ubuntu_2404" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    virtualization-type = "hvm"
    root-device-type    = "ebs"
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical
}

############################################
# VARIABLES: REGION, INSTANCE SETTINGS, NETWORKING, AUTH
############################################

variable "region" {
  default = "us-east-1" # AWS region: US East (Ohio)
}

variable "instance_type" {
  default = "t3.medium" # Default instance type: t3.medium
}

variable "vpc_id" {
  description = "The ID of the VPC to use" # User-supplied VPC ID
  default     = ""                         # Replace this at runtime or via command-line vars
}

variable "subnet_id" {
  description = "The ID of the subnet to use" # User-supplied Subnet ID
  default     = ""                            # Replace this at runtime or via command-line vars
}

############################################
# AMAZON-EBS SOURCE BLOCK: BUILD CUSTOM UBUNTU IMAGE
############################################

source "amazon-ebs" "rstudio_ami" {
  region        = var.region        # Use configured AWS region
  instance_type = var.instance_type # Use configured EC2 instance type
  source_ami    = data.amazon-ami.ubuntu_2404.id
  ssh_username  = "ubuntu"                                        # Default Ubuntu AMI login user
  ami_name      = "rstudio_ami_${replace(timestamp(), ":", "-")}" # Unique AMI name using timestamp
  ssh_interface = "public_ip"                                     # Use public IP for provisioning connection
  vpc_id        = var.vpc_id                                      # Use specific VPC (required for custom networking)
  subnet_id     = var.subnet_id                                   # Use specific subnet (must allow outbound internet)

  # Define EBS volume settings
  launch_block_device_mappings {
    device_name           = "/dev/sda1" # Root device name
    volume_size           = "16"        # Size in GiB for root volume
    volume_type           = "gp3"       # Use gp3 volume for better performance
    delete_on_termination = "true"      # Ensure volume is deleted with instance
  }

  tags = {
    Name = "rstudio_ami_${replace(timestamp(), ":", "-")}" # Tag the AMI with a recognizable name
  }
}

############################################
# BUILD BLOCK: PROVISION FILES AND RUN SETUP SCRIPTS
############################################

build {
  sources = ["source.amazon-ebs.rstudio_ami"] # Use the previously defined EBS source

  # Run install script inside the instance
  provisioner "shell" {
    script          = "./ssm.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Run install script inside the instance
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Run install script inside the instance
  provisioner "shell" {
    script          = "./awscli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Run install script inside the instance
  provisioner "shell" {
    script          = "./rstudio.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

}
