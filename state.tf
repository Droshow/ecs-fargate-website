# This will be a state bucket
terraform {
  backend "s3" {
    bucket  = "state-bucket-ecs-fargate"
    key     = "ecs-fargate"
    region  = "eu-central-1"
    profile = "SolutionArchitect"
  }
}