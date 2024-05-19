terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.regiao_aws
}

resource "aws_launch_template" "maquina" {
  image_id      = "ami-0e001c9271cf7f3b9"
  instance_type = var.instancia
  key_name = var.chave
  
  tags = {
    Name = "Terraform Ansible Python"
  }
  security_group_names = [ var.grupoDeSeguranca ]
  user_data = var.producao ? filebase64("ansible.sh") : ""
}

resource "aws_key_pair" "chaveSSH" {
  key_name = var.chave
  public_key = file("${var.chave}.pub") 
}

resource "aws_autoscaling_lifecycle_hook" "warmup_hook" {
  name                   = "warmup_hook"
  autoscaling_group_name = aws_autoscaling_group.grupo.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 30
  default_result         = "CONTINUE"
}

resource "aws_autoscaling_group" "grupo" {
  availability_zones = [ "${var.regiao_aws}a", "${var.regiao_aws}b" ]
  name = var.nomeGrupo
  max_size = var.maximo
  min_size = var.minimo
  
  #desired_capacity = 1
  target_group_arns = var.producao ? [ aws_lb_target_group.alvoLoadBalancer[0].arn ] : []
  launch_template {
    id = aws_launch_template.maquina.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_schedule" "start_ec2" {
  scheduled_action_name  = "start_ec2"
  min_size               = var.minimo
  max_size               = var.maximo
  desired_capacity       = 2 # Uma maquina ligada
  start_time             = timeadd(timestamp(), "10m")
  recurrence             = "0 7 * * MON-FRI" # CMT +3 (as 7 as maquinas vão ser ligadas)
  time_zone              = "Brazil/West"
  autoscaling_group_name = aws_autoscaling_group.grupo.name
}

resource "aws_autoscaling_schedule" "shutdown_ec2" {
  scheduled_action_name  = "shutdown_ec2"
  min_size               = 1
  max_size               = 2
  desired_capacity       = 1 # Apenas uma maquina ligada
  start_time             = timeadd(timestamp(), "11m")
  recurrence             = "24 18 * * MON-FRI" # CMT +3 (as 18h as maquinas vão ser desligadas)
  time_zone              = "Brazil/West"
  autoscaling_group_name = aws_autoscaling_group.grupo.name
}

resource "aws_default_subnet" "subnet_1" {
  availability_zone = "${var.regiao_aws}a" 
}

resource "aws_default_subnet" "subnet_2" {
  availability_zone = "${var.regiao_aws}b" 
}

resource "aws_lb" "loadBalancer" {
  internal = false
  subnets = [ aws_default_subnet.subnet_1.id, aws_default_subnet.subnet_2.id ]
  security_groups = [ aws_security_group.acesso_geral.id ]
  count = var.producao ? 1 : 0
}

resource "aws_default_vpc" "vpc" {
}

resource "aws_lb_target_group" "alvoLoadBalancer" {
  name = "alvoLoadBalancer"
  port = "8000"
  protocol = "HTTP"
  vpc_id = aws_default_vpc.vpc.id
  count = var.producao ? 1 : 0
}

resource "aws_lb_listener" "entradaLoadBalancer" {
  load_balancer_arn = aws_lb.loadBalancer[0].arn
  port = "8000"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.alvoLoadBalancer[0].arn
  }
  count = var.producao ? 1 : 0
}

resource "aws_autoscaling_policy" "escala-Producao" {
  name = "terraform-escala"
  autoscaling_group_name = var.nomeGrupo
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
  count = var.producao ? 1 : 0
}
