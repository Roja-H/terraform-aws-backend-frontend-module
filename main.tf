#creating a target group
resource "aws_lb_target_group" "main" {
  name     = "${var.project}-${var.environment}-${var.component}"
  port     = local.tg_ports
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check{
   healthy_threshold = 2
   interval  = 5 #for how many sec health check should happen
   matcher = "200-299" #healthy response 
   path = local.health_check_path # in every backend component we have this /health checks healthy or not
   port = local.tg_ports
   timeout = 2 # in 2 second we shld get response
   unhealthy_threshold = 3 # if we get 3 times unhealthy then this is unhealthy
  }
}




resource "aws_instance" "main" { #create ec2 instance(bastion)
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  subnet_id   = local.private_subnet_ids #now we want to choose az 1a soo now convert stringlist to string use slice
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
}

#now configuring instance
# terraform null resource is replaced by terraform data search terraform null resoource there u see terraform data 
resource "terraform_data" "main" {   
  triggers_replace = [
    aws_instance.main.id,
  ]
   
  #search terraform file provisioner 
  provisioner "file" {  #this is used to copy the script and run also to copy file we need connection
  
    source      = "bootstrap.sh"  
    destination = "/tmp/${var.component}.sh"
  
}

 connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
  }

   provisioner "remote-exec" { #after connecting need to execute
    inline = [
      "chmod +x /tmp/${var.component}.sh", #giving execute permission
      "sudo sh /tmp/${var.component}.sh ${var.component} ${var.environment}"  #running the file mongodb here is passing the script
    ]
  }
}


resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
     depends_on = [terraform_data.main] #after completion of creating this block only we can start exceuting this stop instance else all will run at a time in this file
  }

resource "aws_ami_from_instance" "main" {
  name               = "${var.project}-${var.environment}-${var.component}"
  source_instance_id = aws_instance.main.id
  depends_on = [aws_ec2_instance_state.main]
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
}

resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]
  
  # make sure you have aws configure in your laptop
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }

  depends_on = [aws_ami_from_instance.main]
}


# # create a launch template

resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  image_id =  aws_ami_from_instance.main.id #select ami which we created roboshop-dev-catalogue 
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  update_default_version = true # each time you update, new version will become default

  tag_specifications {
    resource_type = "instance"

   # EC2 tags created by ASG(auto scaling group)
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

   # EC2 tags created by ASG (auto scaling group)
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
    )
  }
  # launch template tags
  tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
  )

}


resource "aws_autoscaling_group" "main" {
  name                 = "${var.project}-${var.environment}-${var.component}"
  desired_capacity   = 1
  max_size           = 10
  min_size           = 1
  target_group_arns = [aws_lb_target_group.main.arn]
  vpc_zone_identifier  = local.private_subnet_idss
  health_check_grace_period = 90
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
    )
    content{
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
    
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  timeouts{
    delete = "15m"
  }
}

resource "aws_autoscaling_policy" "main" {
  name                   = "${var.project}-${var.environment}-${var.component}"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = local.apploadbalancer_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.rule_header_url]
    }
  }
}