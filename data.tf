data "aws_ami" "ami" { 
  most_recent    = true
  owners           = ["973714476881"]

  filter {
    name   = "name"
    values = ["Redhat-9-DevOps-Practice"]
    # values = ["RHEL-9-DevOps-Practice"] #create an ami image with name
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


data "aws_ssm_parameter" "sg_id" { #export from ssm
  name = "/${var.project}/${var.environment}/{var.component}_sg_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project}/${var.environment}/private_subnet_ids"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "backend_apploadbalancer_listener_arn" {
  name = "/${var.project}/${var.environment}/backend_apploadbalancer_listener_arn"
}

data "aws_ssm_parameter" "frontend_alb_listener_arn" {
  name = "/${var.project}/${var.environment}/frontend_alb_listener_arn"
}