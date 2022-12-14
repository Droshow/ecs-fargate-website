# This will be a state bucket
terraform {
  backend "s3" {
    bucket         = "terraform-state-ec2-ecs20220813230914197900000001"
    key            = "ecs-fargate"
    region         = "eu-central-1"
    profile = "SolutionArchitect"
  }
}