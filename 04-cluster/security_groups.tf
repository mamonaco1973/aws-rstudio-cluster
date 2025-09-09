# ==========================================================================================
# Security Groups: RStudio Server + Application Load Balancer (ALB)
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Defines network access rules for RStudio Server (port 8787)
#   - Defines network access rules for ALB (port 80)
#   - Provides ICMP (ping) access for diagnostics
#   - Allows all outbound traffic (default egress open)
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# Resource: Security Group for RStudio Server
# - Allows inbound RStudio (port 8787) + ICMP
# - Open to internet for testing (tighten in production)
# ------------------------------------------------------------------------------------------
resource "aws_security_group" "rstudio_sg" {
  name        = "rstudio-security-group-${var.netbios}" # Security group name
  description = "Allow RStudio Server (port 8787) access from the internet"
  vpc_id      = data.aws_vpc.ad_vpc.id # Target VPC

  # Ingress: RStudio web access (port 8787)
  ingress {
    description = "Allow RStudio Server from anywhere"
    from_port   = 8787
    to_port     = 8787
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all IPs
  }

  # Ingress: ICMP (ping)
  ingress {
    description = "Allow ICMP (ping) from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all IPs
  }

  # Egress: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ------------------------------------------------------------------------------------------
# Resource: Security Group for Application Load Balancer (ALB)
# - Allows inbound HTTP (port 80) + ICMP
# - Open to internet for testing (tighten in production)
# ------------------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group-${var.netbios}" # Security group name
  description = "Allow ALB (port 80) access from the internet"
  vpc_id      = data.aws_vpc.ad_vpc.id # Target VPC

  # Ingress: HTTP access (port 80)
  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all IPs
  }

  # Ingress: ICMP (ping)
  ingress {
    description = "Allow ICMP (ping) from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all IPs
  }

  # Egress: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
