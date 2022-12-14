# -- VPC Logs --------------------------------------------------------


module "vpc_flow_logs" {
  source = "./modules/flow-logs"

  for_each = var.flow_log_enabled ? { "logs" = "logs" } : {}

  name              = var.flow_log_config.log_group_name == "" ? "${var.name}-flowlogs" : var.flow_log_config.log_group_name
  vpc_id            = aws_vpc.this.id
  traffic_type      = var.flow_log_config.traffic_type
  iam_path          = "/"
  retention_in_days = var.flow_log_config.retention_in_days
}
