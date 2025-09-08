# Application Load Balancer (ALB) definition
resource "aws_lb" "rstudio_alb" {
  name               = "rstudio-alb" # Name of the ALB
  internal           = false         # ALB is internet-facing
  load_balancer_type = "application" # Load balancer type: Application
  security_groups    = [aws_security_group.alb_sg.id]
  # Associated security group
  subnets = [ # Subnets for ALB deployment
    data.aws_subnet.vm_subnet_1.id,
    data.aws_subnet.vm_subnet_2.id
  ]
}

# Target Group for the ALB
resource "aws_lb_target_group" "rstudio_alb_tg" {
  name     = "rstudio-alb-tg"       # Target group name
  port     = 8787                   # Target group port
  protocol = "HTTP"                 # Target group protocol
  vpc_id   = data.aws_vpc.ad_vpc.id # VPC ID for the target group

  # Health check configuration
  health_check {
    path                = "/"           # Health check path
    interval            = 10            # Interval between checks (seconds)
    timeout             = 5             # Timeout for each check (seconds)
    healthy_threshold   = 3             # Threshold for marking healthy
    unhealthy_threshold = 2             # Threshold for marking unhealthy
    matcher             = "200,300-310" # Expected HTTP response codes
  }
}

# HTTP listener for the ALB
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.rstudio_alb.arn # ARN of the associated ALB
  port              = 80                     # Listener port
  protocol          = "HTTP"                 # Listener protocol

  # Default action configuration
  default_action {
    type             = "forward" # Action type: forward traffic
    target_group_arn = aws_lb_target_group.rstudio_alb_tg.arn
    # Target group ARN
  }
}