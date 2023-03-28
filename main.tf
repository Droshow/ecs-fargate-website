locals {

  project_name = "ecs-fargate-ghost"
  name_context = "${local.project_name}-${terraform.workspace}"
  name         = "${local.project_name}-${terraform.workspace}"

  global_tag = {
    Billing = "Billing Account 01"
  }

  project_tag = {
    Environment = terraform.workspace
    Project     = local.project_name
  }

  tags = merge(local.global_tag, local.project_tag)

  region = "eu-central-1"

}
################
#SECURITY GROUPS
################
module "security" {
  source    = "./modules/security"
  vpc_id    = module.vpc.vpc_id
  site_name = var.site_name

}

#############
#VPC
#############

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.project_tag.Project
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", ]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", ]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", ]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = local.project_tag.Environment
  }
}

#############
#ECS
#############
#### ECS tasks should be in private subnets, but does it work with autoscaling then?

module "ecs" {
  source                                    = "./modules/ecs"
  cluster_count                             = 1
  region                                    = var.region
  site_name                                 = var.site_name
  cluster_name                              = var.cluster_name
  capacity_provider                         = var.capacity_provider
  container_name                            = var.container_name
  container_image                           = var.container_image
  family                                    = var.family
  network_mode                              = var.network_mode
  execution_role_arn                        = module.iam.iam_role
  task_role_arn                             = module.iam.iam_role
  subnets                                   = module.vpc.private_subnets
  vpc_id                                    = module.vpc.vpc_id
  lb_target_group_arn                       = module.loadbalancer.lb_target_group_arn
  efs_sg                                    = module.security.efs_sg
  cpu                                       = 256
  memory                                    = 512
  container_port                            = 2368
  host_port                                 = 2368
  assign_public_ip                          = true
  default_capacity_provider_strategy_base   = 1
  default_capacity_provider_strategy_weight = 100
  container_definitions_essential           = true
  sg-container                              = module.security.fargate_task
  ecs_subnet_id                             = module.security.fargate_task

  depends_on = [module.vpc]
}
#############
#LOADBALANCER
#############
module "loadbalancer" {
  source                     = "./modules/loadbalancer"
  name                       = var.lb_name
  internal                   = false
  lb_type                    = var.lb_type
  vpc_id                     = module.vpc.vpc_id
  lb_sg                      = module.security.fargate_task
  subnets                    = module.vpc.public_subnets
  default_sg                 = module.security.fargate_sg_default
  lb_listener_port           = 80
  lb_listener_portocol       = "HTTP"
  listener_action_type       = "forward"
  target_group_port          = 2386
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
#############
#Cloudfront
#############
module "cloudfront" {
  source            = "./modules/cloudfront"
  distribution_name = "${var.site_name}-distribution"
  site_name         = var.site_name
  alb_domain        = module.loadbalancer.lb_endpoint
  dns_domain        = var.dns_domain
  dns_record        = var.dns_record
}

