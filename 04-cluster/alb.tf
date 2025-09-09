# ==========================================================================================
# Application Load Balancer (ALB) + Target Group + Listener
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Deploys an internet-facing Application Load Balancer (ALB)
#   - Associates with public subnets and a security group
#   - Creates a target group for RStudio (port 8787) with stickiness + health checks
#   - Configures an HTTP listener (port 80) forwarding traffic to the target group
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# Resource: Application Load Balancer (ALB)
# - Internet-facing ALB for routing requests to backend targets
# ------------------------------------------------------------------------------------------
resource "aws_lb" "rstudio_alb" {
  name               = "rstudio-alb"                  # ALB name
  internal           = false                          # Internet-facing
  load_balancer_type = "application"                  # ALB type
  security_groups    = [aws_security_group.alb_sg.id] # Security group association

  subnets = [ # Public subnets for ALB placement
    data.aws_subnet.pub_subnet_1.id,
    data.aws_subnet.pub_subnet_2.id
  ]
}


# ------------------------------------------------------------------------------------------
# Resource: Target Group for ALB
# - Defines RStudio backend pool with sticky sessions + health checks
# ------------------------------------------------------------------------------------------
resource "aws_lb_target_group" "rstudio_alb_tg" {
  name     = "rstudio-alb-tg"       # Target group name
  port     = 8787                   # RStudio port
  protocol = "HTTP"                 # Protocol
  vpc_id   = data.aws_vpc.ad_vpc.id # Target VPC

  # Sticky session configuration
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 1 day (in seconds)
    enabled         = true
  }

  # Health check configuration
  health_check {
    path                = "/"           # Health check path
    interval            = 10            # Interval between checks (seconds)
    timeout             = 5             # Timeout for each check (seconds)
    healthy_threshold   = 3             # # consecutive successes = healthy
    unhealthy_threshold = 2             # # consecutive failures = unhealthy
    matcher             = "200,300-310" # Expected response codes
  }
}


# ------------------------------------------------------------------------------------------
# Resource: HTTP Listener
# - Listens on port 80 and forwards traffic to the target group
# ------------------------------------------------------------------------------------------
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.rstudio_alb.arn # ALB ARN
  port              = 80                     # Listener port
  protocol          = "HTTP"                 # Protocol

  # Default action: forward requests to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rstudio_alb_tg.arn # Target group ARN
  }
}
