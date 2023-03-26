####################
#ECS SECURITY GROUPS
####################

resource "aws_security_group" "fargate_task" {
  #TODO add it to ecs programatically
  name        = "ECS_security_group"
  description = "security group for fargate"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_default_security_group" "fargate_default" {
  vpc_id = var.vpc_id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

####################
#EFS SECURITY GROUPS
####################

resource "aws_security_group" "efs_security_group" {
  name        = "${var.site_name}_efs_sg"
  description = "security group for efs for ghost"
  vpc_id      = var.vpc_id
}
resource "aws_security_group_rule" "efs_ingress" {

  security_group_id = aws_security_group.efs_security_group.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Ingress to EFS mount from ghost container"
}


resource "aws_security_group_rule" "efs_egress" {
  security_group_id = aws_security_group.efs_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
}
