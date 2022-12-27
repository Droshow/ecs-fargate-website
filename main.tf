locals {

    project_name = "ecs-fargate-ghost"
    name_context = "${local.project_name}-${terraform.workspace}"
    name = "${local.project_name}-${terraform.workspace}"

    global_tag = {
        Billing     = "Billing Account 01"
    }

    project_tag = {
        Environment = terraform.workspace
        Project     = local.project_name
    }

    tags  = merge(local.global_tag,local.project_tag)

    region = "eu-central-1"

}
################
#SECURITY GROUPS
################
resource "aws_security_group" "fargate" {
  name        = "HTTP_Access"
  description = "Allow HTTP/SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_default_security_group" "fargate_default" {
  vpc_id = module.vpc.vpc_id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############
#VPC
#############

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "starting vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = locals.project_tag.Environment
  }
}

#############
#ECS
#############
module "ecs" {
  source                                    = "./modules/ecs"
  cluster_count                             = 1
  cluster_name                              = var.cluster_name
  capacity_provider                         = var.capacity_provider
  container_name                            = var.container_name
  # container_image                           = var.container_image
  family                                    = var.family
  network_mode                              = var.network_mode
  execution_role_arn                        = module.iam.iam_role
  task_role_arn                             = module.iam.iam_role
  subnets                                   = module.networking.subnet
  lb_target_group_arn                       = module.loadbalancer.lb_target_group_arn
  cpu                                       = 256
  memory                                    = 512
  container_port                            = 80
  host_port                                 = 80
  assign_public_ip                          = true
  default_capacity_provider_strategy_base   = 1
  default_capacity_provider_strategy_weight = 100
  container_definitions_essential           = true
}
#############
#LOADBALANCER
#############
module "loadbalancer" {
  source                     = "./modules/loadbalancer"
  name                       = var.lb_name
  internal                   = false
  lb_type                    = var.lb_type
  vpc_id                     = module.networking.vpc_id
  lb_sg                      = module.security.fargate_sg
  subnets                    = module.networking.subnet
  default_sg                 = module.security.fargate_sg_default
  lb_listener_port           = 80
  lb_listener_portocol       = "HTTP"
  listener_action_type       = "forward"
  target_group_port          = 80
  tg_protocol                = "HTTP"
  target_type                = "ip"
  enable_deletion_protection = false
}
#############
#AUTOSCALING
#############
module "autoscaling" {
  source                 = "./modules/autoscaling"
  name                   = var.asg_name
  max_capacity           = 2
  min_capacity           = 1
  resource_id            = "service/${var.cluster_name}/${var.cluster_name}"
  scalable_dimension     = var.scalable_dimension
  service_namespace      = var.service_namespace
  ecs_cluster            = var.cluster_name
  ecs_service            = var.cluster_name
  policy_type            = var.policy_type
  predefined_metric_type = var.predefined_metric_type
  target_value           = 80
}
#############
#IAM
#############
module "iam" {
  source                 = "./modules/iam"
  name                   = var.policy_name
  policy_name            = var.policy_name
  path                   = "/"
  iam_policy_description = var.iam_policy_description
  iam_policy             = file("./fargate-policy.json")
  assume_role_policy     = file("./fargate-trusted-identity.json")

}


