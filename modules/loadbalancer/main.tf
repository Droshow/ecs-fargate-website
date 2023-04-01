resource "aws_lb" "fargate" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = var.lb_type
  security_groups    = [var.lb_sg, var.default_sg]

  subnets = var.subnets

  enable_deletion_protection = var.enable_deletion_protection

}

resource "aws_lb_listener" "fargate" {
  load_balancer_arn = aws_lb.fargate.arn
  port              = var.lb_listener_port
  protocol          = var.lb_listener_portocol

  default_action {
    type             = var.listener_action_type
    target_group_arn = aws_lb_target_group.fargate.arn
  }
}

resource "aws_lb_target_group" "fargate" {
  name        = var.name
  port        = var.target_group_port
  protocol    = var.tg_protocol
  vpc_id      = var.vpc_id
  target_type = var.target_type
}


resource "aws_lb_listener_rule" "cloudfront_only" {
  listener_arn = aws_lb_listener.fargate.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fargate.arn
  }

  condition {
    http_header {
      http_header_name = "X-CloudFront-Access"
      values           = ["This-is-martins-special-header"]
    }
  }
}

resource "aws_lb_listener_rule" "deny_other_traffic" {
  listener_arn = aws_lb_listener.fargate.arn
  priority     = 20

  action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Access Denied"
      status_code  = "403"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
