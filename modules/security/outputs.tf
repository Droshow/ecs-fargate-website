output "fargate_task" {
  value = aws_security_group.fargate_task.id
}

output "fargate_sg_default" {
  value = aws_default_security_group.fargate_default.id
}