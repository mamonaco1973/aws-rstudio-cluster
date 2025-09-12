# ==========================================================================================
# Auto Scaling: CloudWatch Alarm + Scaling Policy + Auto Scaling Group (ASG)
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Monitors EC2 CPU utilization via CloudWatch
#   - Triggers a scale-up policy when CPU > 60% for 1 minute
#   - Defines an Auto Scaling Group (ASG) tied to launch template + ALB
#   - Ensures RStudio infrastructure scales horizontally under load
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# Resource: CloudWatch Alarm
# - Fires when average CPU utilization exceeds threshold
# - Associated with Auto Scaling Group
# ------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "HighCPUUtilization"   # Alarm name
  comparison_operator = "GreaterThanThreshold" # Trigger if metric > threshold
  evaluation_periods  = 2                      # # of consecutive periods
  metric_name         = "CPUUtilization"       # Metric to monitor
  namespace           = "AWS/EC2"              # Metric namespace
  period              = 30                     # Evaluation period (seconds)
  statistic           = "Average"              # Aggregation function
  threshold           = 60                     # CPU % threshold
  alarm_description   = "Scale up if CPUUtilization > 60% for 1 minute"
  actions_enabled     = true # Enable alarm actions

  # Attach alarm to the Auto Scaling Group
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.rstudio_asg.name
  }

  # Action: invoke scale-up policy
  alarm_actions = [aws_autoscaling_policy.scale_up_policy.arn]
}


# ------------------------------------------------------------------------------------------
# Resource: Auto Scaling Policy (Scale-Up)
# - Increases capacity by 1 instance when triggered
# ------------------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale-up-policy"                      # Policy name
  scaling_adjustment     = 1                                      # Add 1 instance
  adjustment_type        = "ChangeInCapacity"                     # Mode: fixed increment
  cooldown               = 120                                    # Wait 2 minutes before next action
  autoscaling_group_name = aws_autoscaling_group.rstudio_asg.name # Target ASG
}


# ------------------------------------------------------------------------------------------
# Resource: Auto Scaling Group (ASG)
# - Launches and manages RStudio instances across subnets
# - Integrates with ALB target group for health checks
# ------------------------------------------------------------------------------------------
resource "aws_autoscaling_group" "rstudio_asg" {
  # Launch template defining EC2 instance configuration
  launch_template {
    id      = aws_launch_template.rstudio_launch_template.id # Launch template ID
    version = "$Latest"                                      # Always use latest template version
  }

  name = "rstudio-asg" # ASG name

  vpc_zone_identifier = [ # Subnets to place instances in
    data.aws_subnet.vm_subnet_1.id,
    data.aws_subnet.vm_subnet_2.id
  ]

  desired_capacity          = 2     # Desired instance count
  max_size                  = 4     # Max instances
  min_size                  = 2     # Min instances
  health_check_type         = "ELB" # Use ALB health checks
  health_check_grace_period = 300   # Wait 5 min before health evaluation
  default_cooldown          = 120   # Cooldown between scaling actions
  default_instance_warmup   = 300   # Align warmup with grace period

  target_group_arns = [aws_lb_target_group.rstudio_alb_tg.arn] # Attach ALB target group

  depends_on = [aws_lb.rstudio_alb] # Ensure ALB exists first
}
