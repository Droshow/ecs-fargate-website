
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "aws_kms_key" "this" {
  description             = "KMS Key for log group with name: ${var.name}"
  deletion_window_in_days = 7
  tags                    = var.tags
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key_policy.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}-Flowlogs-KMS-Key"
  target_key_id = aws_kms_key.this.id
}


locals {
  root_account_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

data "aws_iam_policy_document" "key_policy" {

  statement {
    sid     = "Enable IAM User Permissions"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = [local.root_account_arn]
    }
    resources = ["*"]
  }

  statement {
    sid    = "Allow Usage By CloudWatch"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.name}"]
    }

  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_in_days
  tags              = var.tags
  kms_key_id        = aws_kms_key.this.arn
}


resource "aws_flow_log" "this" {

  traffic_type         = var.traffic_type
  log_destination      = aws_cloudwatch_log_group.this.arn
  log_destination_type = "cloud-watch-logs" # cloud-watch-logs or s3
  iam_role_arn         = aws_iam_role.flowlogs.arn
  tags                 = merge({ Name = "${var.name}-flow-logs" }, var.tags)

  vpc_id    = var.vpc_id
  #subnet_id = ""
  

  max_aggregation_interval = 60 # 60 or 600

  # destination_options {
  #   file_format                = "parquet" # plain-text
  #   hive_compatible_partitions = true
  #   per_hour_partition         = true
  # }
}

resource "aws_iam_role" "flowlogs" {
  name               = "${var.name}-FlowLogsRole"
  description        = "Flowlogs Role for VPC ${var.name}"
  path               = var.iam_path
  assume_role_policy = data.aws_iam_policy_document.assume_role_flow_logs.json
}

resource "aws_iam_role_policy_attachment" "flow_logs" {
  role       = aws_iam_role.flowlogs.name
  policy_arn = aws_iam_policy.flow_logs.arn
}

data "aws_iam_policy_document" "assume_role_flow_logs" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "flow_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [aws_cloudwatch_log_group.this.arn]
  }
}

resource "aws_iam_policy" "flow_logs" {
  name        = "${var.name}-FlowLogsPolicy"
  description = "Flowlogs Policy for VPC ${var.name}"
  path        = var.iam_path
  policy      = data.aws_iam_policy_document.flow_logs_policy.json
  tags        = var.tags
}

