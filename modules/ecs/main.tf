# --- module/ecs/main

resource "aws_ecs_cluster" "os_system" {
  name = var.cluster_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.os_system.name

  capacity_providers = [var.capacity_provider]

  default_capacity_provider_strategy {
    base              = var.default_capacity_provider_strategy_base
    weight            = var.default_capacity_provider_strategy_weight
    capacity_provider = var.capacity_provider
  }
}

resource "aws_ecs_task_definition" "os_system" {
  family                   = var.family
  requires_compatibilities = [var.capacity_provider]
  network_mode             = var.network_mode
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      cpu       = var.cpu
      memory    = var.memory
      essential = var.container_definitions_essential
      logConfiguration : {
        logDriver = "awslogs",
        options = {
          awslogs-create-group  = "true",
          awslogs-group         = "/ecs/ubuntu",
          awslogs-region        = "eu-central-1",
          awslogs-stream-prefix = "ecs"
      } }

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.host_port
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "${var.site_name}_ghost_persistent",
          containerPath = "/var/lib/ghost/content"
        }
      ]

    },
  ])
  volume {
    name = "${var.site_name}_ghost_persistent"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ghost_persistent.id
      root_directory     = ""
      transit_encryption = "DISABLED"
      authorization_config {
        #       access_point_id = aws_efs_access_point.ghost_efs.id
        iam = "DISABLED"
      }
    }
  }
}
resource "aws_ecs_service" "os_system" {
  name            = var.cluster_name
  cluster         = aws_ecs_cluster.os_system.id
  task_definition = aws_ecs_task_definition.os_system.arn
  desired_count   = var.cluster_count
  load_balancer {
    target_group_arn = var.lb_target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 1

  }
  network_configuration {
    subnets = var.subnets
    #assign_public_ip = var.assign_public_ip
    security_groups = [var.sg-container]
  }
}

#########
#EFS
#########
resource "aws_efs_file_system" "ghost_persistent" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
  tags = {
    "Name" = "${var.site_name}_ghost_persistent"
  }
}

resource "aws_efs_access_point" "ghost_efs" {
  file_system_id = aws_efs_file_system.ghost_persistent.id
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow EFS access"
  vpc_id      = var.vpc_id
}

resource "aws_efs_mount_target" "ghost_efs" {
  count           = length(var.subnets)
  file_system_id  = aws_efs_file_system.ghost_persistent.id
  subnet_id       = var.subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

#########
# VPC Endpoint
#########

# Create the VPC endpoint for EFS
# resource "aws_vpc_endpoint" "efs" {
#   vpc_id              = module.vpc.id
#   service_name        = "com.amazonaws.${var.region}.elasticfilesystem"
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.fargate.id]
#   subnet_ids          = module.subnets.ids
# }

# # Create the VPC endpoint for CloudFront
# resource "aws_vpc_endpoint" "ecs" {
#   vpc_id       = var.vpc_id
#   service_name = "com.amazonaws.${var.region}.cloudfront"
#   vpc_endpoint_type = "Interface"
#   subnet_ids = var.subnets
# }