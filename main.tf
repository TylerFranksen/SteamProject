# Define the AWS provider and region
provider "aws" {
  region = "us-west-2"  # Update with your desired AWS region
}

# Create an Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "steam_app" {
  name        = "steam-app"
  description = "Steam Application"
}

# Create an Elastic Beanstalk environment for each stage
locals {
  environments = ["sandbox", "build", "staging", "production"]
}

resource "aws_elastic_beanstalk_environment" "steam_env" {
  count       = length(local.environments)
  name        = "steam-${local.environments[count.index]}"
  application = aws_elastic_beanstalk_application.steam_app.name
  solution_stack_name = "64bit Amazon Linux 2 v5.4.0 running Docker"  # Update with desired Docker solution stack
}

# Create an AWS CloudWatch log group for each environment
resource "aws_cloudwatch_log_group" "steam_logs" {
  count = length(local.environments)
  name  = "/aws/elasticbeanstalk/steam-${local.environments[count.index]}"
}

# Configure Auto Scaling Group and Application Load Balancer
resource "aws_elastic_beanstalk_environment" "steam_env" {
  count       = length(local.environments)
  name        = "steam-${local.environments[count.index]}"
  application = aws_elastic_beanstalk_application.steam_app.name
  solution_stack_name = "64bit Amazon Linux 2 v5.4.0 running Docker"  # Update with desired Docker solution stack

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"  # Minimum number of instances in the Auto Scaling Group
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "4"  # Maximum number of instances in the Auto Scaling Group
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "CoolDown"
    value     = "300"  # Cool down period in seconds
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "ListenerEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "ListenerPort"
    value     = "80"
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "Protocol"
    value     = "HTTP"
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "Rules"
    value     = <<EOF
[{
  "Name": "default",
  "Priority": "1",
  "Conditions": [
    {
      "Field": "path-pattern",
      "PathPatternConfig": {"Values": ["/*"]}
    }
  ],
  "Actions": [
    {
      "Type": "forward",
      "TargetGroupArn": "${aws_lb_target_group.steam_lb_target[count.index].arn}"
    }
  ]
}]
EOF
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"  # Use "LoadBalanced" for Application Load Balancer
  }
}

# Create an Application Load Balancer and target group
resource "aws_lb" "steam_lb" {
  count = length(local.environments)
  name  = "steam-${local.environments[count.index]}-lb"
  load_balancer_type = "application"
  subnets = ["subnet-12345678", "subnet-87654321"]  # Update with your desired subnets

  tags = {
    Name = "steam-${local.environments[count.index]}-lb"
  }
}

resource "aws_lb_target_group" "steam_lb_target" {
  count = length(local.environments)
  name     = "steam-${local.environments[count.index]}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-12345678"  # Update with your desired VPC ID

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 5
  }

  tags = {
    Name = "steam-${local.environments[count.index]}-tg"
  }
}

# Attach the target group to the environment's Load Balancer
resource "aws_elastic_beanstalk_environment" "steam_env" {
  count       = length(local.environments)
  name        = "steam-${local.environments[count.index]}"
  application = aws_elastic_beanstalk_application.steam_app.name
  solution_stack_name = "64bit Amazon Linux 2 v5.4.0 running Docker"  # Update with desired Docker solution stack

  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "ManagedSecurityGroup"
    value     = "${aws_lb.steam_lb[count.index].security_groups[0]}"
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "DefaultProcess"
    value     = "default"
  }

  setting {
    namespace = "aws:elbv2:listener:default"
    name      = "Rules"
    value     = <<EOF
[{
  "Name": "default",
  "Priority": "1",
  "Conditions": [
    {
      "Field": "path-pattern",
      "PathPatternConfig": {"Values": ["/*"]}
    }
  ],
  "Actions": [
    {
      "Type": "forward",
      "TargetGroupArn": "${aws_lb_target_group.steam_lb_target[count.index].arn}"
    }
  ]
}]
EOF
  }
}
