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


#####################################################
#VPC // Using external one not Auvaria for time-being
#####################################################


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name}-ghost-vpc"
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
resource "aws_ecs_task_definition" "ghost_container" {
  family = "${var.site_name}_ghost"
  container_definitions = templatefile("${path.module}/task-definitions/ghost.json", {
    db_host                  = aws_rds_cluster.serverless_ghost.endpoint,
    db_user                  = aws_rds_cluster.serverless_ghost.master_username,
    db_password              = random_password.serverless_ghost_password.result,
    db_name                  = aws_rds_cluster.serverless_ghost.database_name,
    ghost_image          = "${aws_ecr_repository.serverless_ghost.repository_url}:latest",
    wp_dest                  = "https://${var.site_prefix}.${var.site_domain}",
    wp_region                = var.s3_region,
    wp_bucket                = module.cloudfront.ghost_bucket_id,
    container_dns            = "${var.ghost_subdomain}.${var.site_domain}",
    container_dns_zone       = var.hosted_zone_id,
    container_cpu            = var.ecs_cpu,
    container_memory         = var.ecs_memory
    efs_source_volume        = "${var.site_name}_ghost_persistent"
    ghost_admin_user     = var.ghost_admin_user
    ghost_admin_password = var.ghost_admin_password
    ghost_admin_email    = var.ghost_admin_email
    site_name                = var.site_name
  })

  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ghost_task.arn
  task_role_arn            = aws_iam_role.ghost_task.arn

  volume {
    name = "${var.site_name}_ghost_persistent"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ghost_persistent.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.ghost_efs.id
      }
    }

  }
  tags = {
    "Name" = "${var.site_name}_ghostECS"
  }

  depends_on = [
    aws_efs_file_system.ghost_persistent
  ]
}

###########################
# SECURITY GROUPS FOR GHOST
###########################

resource "aws_security_group" "ghost_security_group" {
  name        = "${var.site_name}_ghost_sg"
  description = "security group for ghost"
  vpc_id      = var.main_vpc_id
}

resource "aws_security_group_rule" "ghost_sg_ingress_80" {
  security_group_id = aws_security_group.ghost_security_group.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  #tfsec:ignore:AWS006
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow ingress from world to ghost container"
}

resource "aws_security_group_rule" "ghost_sg_egress_2049" {
  security_group_id        = aws_security_group.ghost_security_group.id
  source_security_group_id = aws_security_group.efs_security_group.id
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
  description              = "Egress to EFS mount from ghost container"
}

resource "aws_security_group_rule" "ghost_sg_egress_80" {
  security_group_id = aws_security_group.ghost_security_group.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  #tfsec:ignore:AWS007
  cidr_blocks = ["0.0.0.0/0"]
  description = "Egress from ghost container to world on HTTP"
}

resource "aws_security_group_rule" "ghost_sg_egress_443" {
  security_group_id = aws_security_group.ghost_security_group.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  #tfsec:ignore:AWS007
  cidr_blocks = ["0.0.0.0/0"]
  description = "Egress from ghost container to world on HTTPS"
}


resource "aws_security_group_rule" "ghost_sg_egress_3306" {
  security_group_id        = aws_security_group.ghost_security_group.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.aurora_serverless_group.id
  description              = "Egress from ghost container to Aurora Database"
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
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

######################################
#OTHERS FOR INSTANCE S3 Policies & EFS
######################################

data "aws_iam_policy_document" "ghost_bucket_access" {
  statement {
    actions   = ["s3:ListBucket"]
    effect    = "Allow"
    resources = [module.cloudfront.ghost_bucket_arn]
  }
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    effect    = "Allow"
    resources = ["${module.cloudfront.ghost_bucket_arn}/*"]
  }
  statement {
    actions   = ["ec2:DescribeNetworkInterfaces"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }
}

resource "aws_efs_file_system" "ghost_persistent" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
  tags = {
    "Name" = "${var.site_name}_ghost_persistent"
  }
}

resource "aws_iam_policy" "ghost_bucket_access" {
  name        = "${var.site_name}_ghostBucketAccess"
  description = "The role that allows ghost task to do necessary operations"
  policy      = data.aws_iam_policy_document.ghost_bucket_access.json
}

resource "aws_iam_role_policy_attachment" "ghost_bucket_access" {
  role       = aws_iam_role.ghost_task.name
  policy_arn = aws_iam_policy.ghost_bucket_access.arn
}

resource "aws_iam_role" "ghost_task" {
  name               = "${var.site_name}_ghostTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ghost_role_attachment_ecs" {
  role       = aws_iam_role.ghost_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ghost_role_attachment_cloudwatch" {
  role       = aws_iam_role.ghost_task.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_efs_access_point" "ghost_efs" {
  file_system_id = aws_efs_file_system.ghost_persistent.id
}

resource "aws_security_group" "efs_security_group" {
  name        = "${var.site_name}_efs_sg"
  description = "security group for ghost"
  vpc_id      = var.main_vpc_id
}

resource "aws_security_group_rule" "efs_ingress" {
  security_group_id        = aws_security_group.efs_security_group.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.ghost_security_group.id
  description              = "Ingress to EFS mount from ghost container"
}

resource "aws_efs_mount_target" "ghost_efs" {
  for_each        = toset(var.subnet_ids)
  file_system_id  = aws_efs_file_system.ghost_persistent.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_cloudwatch_log_group" "ghost_container" {
  name              = "/aws/ecs/${var.site_name}-serverless-ghost-container"
  retention_in_days = 7
}
