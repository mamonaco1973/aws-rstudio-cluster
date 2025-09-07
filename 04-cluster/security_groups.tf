# ------------------------------------------------------------
# Security Group for RStudio Server (Port 8787)
# Used to allow web access to the RStudio Server interface
# ------------------------------------------------------------
resource "aws_security_group" "rstudio_sg" {
  name        = "rstudio-security-group-${var.netbios}"   # Security Group name
  description = "Allow RStudio Server (port 8787) access from the internet"
  vpc_id      = data.aws_vpc.ad_vpc.id                # Associates the security group with the specified VPC

  # INGRESS: Defines inbound rules allowing access to port 8787 (RStudio default port)
  ingress {
    description = "Allow RStudio Server from anywhere"
    from_port   = 8787                      # Start of port range (RStudio default port)
    to_port     = 8787                      # End of port range (same as start for a single port)
    protocol    = "tcp"                     # Protocol type (TCP for web interface)
    cidr_blocks = ["0.0.0.0/0"]             # WARNING: Allows traffic from ANY IP (lock down in production)
  }

  # INGRESS: Defines inbound rules allowing ICMP (ping)
  ingress {
    description = "Allow ICMP (ping) from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]             # WARNING: open to all IPs (fine for testing, restrict later)
  }

  # EGRESS: Allows all outbound traffic (default open rule)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

