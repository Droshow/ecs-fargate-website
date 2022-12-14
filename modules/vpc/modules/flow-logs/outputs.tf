
output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}

output "cloudwatch_log_group_arn" {
  value = aws_cloudwatch_log_group.this.arn
}


output "role_name" {
  value = aws_iam_role.flowlogs.name
}

output "role_arn" {
  value = aws_iam_role.flowlogs.arn
}

output "policy_name" {
  value = aws_iam_policy.flow_logs.name
}

output "policy_arn" {
  value = aws_iam_policy.flow_logs.arn
}

output "kms_key_id" {
  value = aws_kms_key.this.key_id
}

output "kms_key_arn" {
  value = aws_kms_key.this.arn
}
