output "ecs_cluster_name" {
  value = aws_ecs_cluster.os_system.name
}

output "ecs_service_id" {
  value = aws_ecs_cluster.os_system.id
}

# output "ecs_vpc_endpoint" {
#   value = aws_vpc_endpoint.ecs.id  
# }