# ---- root/main

variable "container_name" {
  default = "ghost_image"
}
variable "container_image" {
  default = "961477247679.dkr.ecr.eu-central-1.amazonaws.com/digidocs:ghost-development"
}
variable "cluster_name" {
  default = "ghost"
}
variable "capacity_provider" {
  default = "FARGATE"
}
variable "family" {
  default = "ghost"
}
variable "network_mode" {
  default = "awsvpc"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
variable "lb_name" {
  default = "fargate"
}
variable "lb_type" {
  default = "application"
}
variable "iam_policy_description" {
  default = "Policy for container to pull from ECR"
}
variable "policy_type" {
  default = "TargetTrackingScaling"
}
variable "asg_name" {
  default = "fargate"
}
variable "scalable_dimension" {
  default = "ecs:service:DesiredCount"
}
variable "service_namespace" {
  default = "ecs"
}
variable "iam_role_name" {
  default = "fargate_role"
}
variable "policy_name" {
  default = "Fargate-Policy"
}
variable "predefined_metric_type" {
  default = "ECSServiceAverageCPUUtilization"
}

variable "site_name" {
  default = "mojowa"
}

variable "region" {
  default = "eu-central-1"
}
# variable "waf_name" {
#   default = "waf-fargate"
# }
