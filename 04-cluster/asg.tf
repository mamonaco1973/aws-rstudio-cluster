# CloudWatch Alarm to scale up the Auto Scaling Group when CPU utilization exceeds 80%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "HighCPUUtilization"   # Alarm name
  comparison_operator = "GreaterThanThreshold" # Trigger when metric exceeds threshold
  evaluation_periods  = 2                      # Consecutive periods to breach threshold
  metric_name         = "CPUUtilization"       # Metric to monitor
  namespace           = "AWS/EC2"              # AWS namespace for the metric
  period              = 30                     # Duration of each evaluation period (seconds)
  statistic           = "Average"              # Aggregation type for the metric
  threshold           = 60                     # Threshold for triggering the alarm
  alarm_description   = "Scale up if CPUUtilization > 60% for 1 minute"
  actions_enabled     = true # Enable alarm actions

  # Metric dimensions to associate the alarm with the Auto Scaling Group
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.rstudio_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up_policy.arn] # Action to execute when alarm triggers
}

# Scaling policy to increase the number of instances in the Auto Scaling Group
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale-up-policy"                      # Scaling policy name
  scaling_adjustment     = 1                                      # Number of instances to add
  adjustment_type        = "ChangeInCapacity"                     # Scaling method: add fixed number
  cooldown               = 120                                    # Cooldown period before next scaling action
  autoscaling_group_name = aws_autoscaling_group.rstudio_asg.name # Associated Auto Scaling Group
}

# Auto Scaling Group (ASG) definition
resource "aws_autoscaling_group" "rstudio_asg" {
  # Launch template for EC2 instance configuration
  launch_template {
    id      = aws_launch_template.rstudio_launch_template.id # Launch template ID
    version = "$Latest"                                      # Latest version of the launch template
  }

  name = "rstudio-asg"    # Auto Scaling Group name
  vpc_zone_identifier = [ # Subnets for the ASG
    data.aws_subnet.vm_subnet_1.id,
    data.aws_subnet.vm_subnet_2.id
  ]
  desired_capacity          = 1     # Desired number of instances
  max_size                  = 1     # Maximum number of instances
  min_size                  = 1     # Minimum number of instances
  health_check_type         = "ELB" # Health check type (ELB-based)
  health_check_grace_period = 300   # wait 5 minutes before evaluating health
  default_cooldown          = 120   # (you might also want to slow this down)
  default_instance_warmup   = 300   # aligns warmup with grace period

  target_group_arns = [aws_lb_target_group.rstudio_alb_tg.arn] #  Associated ALB target group
}