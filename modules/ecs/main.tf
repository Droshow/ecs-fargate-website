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
      efs_source_volume        = "Ghost-persistent"
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
      ]
    },
  ])
  volume {
    name = "${var.site_name}_ghost_persistent"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.ghost_persistent.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.ghost_efs.id
        iam             = "ENABLED"
      }
    }
        }
  depends_on = [
    aws_efs_file_system.ghost_persistent
  ]
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
    subnets          = var.subnets
    assign_public_ip = var.assign_public_ip
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

resource "aws_efs_mount_target" "ghost_efs" {
  for_each        = toset(var.subnets)
  file_system_id  = aws_efs_file_system.ghost_persistent.id
  subnet_id= each.value
}