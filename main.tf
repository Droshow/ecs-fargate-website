locals {


    project_name = "ecs-fargate-digidocs"
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


######################
#VPC
######################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", ]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", ]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24",]

  enable_nat_gateway = false
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


######################
#ECS
######################


module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "ecs-fargate"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }
}

######################
#CLOUDFRONT
######################

module "cloudfront" {
  source             = "./modules/cloudfront"
  site_name          = var.site_name
  site_domain        = var.site_domain
  cloudfront_ssl     = aws_acm_certificate.ghost_site.arn
  cloudfront_aliases = var.cloudfront_aliases
  depends_on = [aws_acm_certificate_validation.ghost_site,
  module.waf]
  cloudfront_class = var.cloudfront_class
  waf_acl_arn      = var.waf_enabled ? module.waf[0].waf_acl_arn : null
}