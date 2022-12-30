# ----- module/ecs/variable
variable "container_name" {}
variable "container_image" {}
variable "cluster_name" {}
variable "capacity_provider" {}
variable "family" {}
variable "network_mode" {}
variable "execution_role_arn" {}
variable "task_role_arn" {}
variable "the_vpc_id" {}
variable "subnets" {}
variable "lb_target_group_arn" {}
variable "cpu" {}
variable "memory" {}
variable "container_port" {}
variable "host_port" {}
variable "assign_public_ip" {}
variable "cluster_count" {}
variable "default_capacity_provider_strategy_base" {}
variable "default_capacity_provider_strategy_weight" {}
variable "container_definitions_essential" {}
variable "site_name" {}

# variable "site_domain" {
#   type        = string
#   description = "The site domain name to configure (without any subdomains such as 'www')"
# }