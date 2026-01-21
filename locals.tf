locals{
    ami_id = data.aws_ami.ami.id
    vpc_id = data.aws_ssm_parameter.vpc_id.value

    tg_ports = "${var.component}" == "frontend" ? 80 : 8080
    health_check_path = "${var.component}" == "frontend" ? "/" : "/health"

    sg_id = data.aws_ssm_parameter.sg_id.value

    private_subnet_ids = split(",",data.aws_ssm_parameter.private_subnet_ids.value)[0]
    private_subnet_idss = split ("," , data.aws_ssm_parameter.private_subnet_ids.value)

    backend_alb_listener_arn = data.aws_ssm_parameter.backend_apploadbalancer_listener_arn.value
    frontend_alb_listener_arn = data.aws_ssm_parameter.frontend_alb_listener_arn.value

    apploadbalancer_listener_arn = "${var.component}" == "frontend" ? local.frontend_alb_listener_arn : local.backend_alb_listener_arn


    rule_header_url = "${var.component}" == "frontend" ? "${var.environment}.${var.zone_name}" : "${var.component}.backend-${var.environment}.${var.zone_name}"

    common_tags = {
        project = "roboshop"
        environment = "dev"
        Terraform = "true"
    }
}