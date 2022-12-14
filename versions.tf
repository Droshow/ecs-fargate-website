terraform {
  required_providers {
    aws = {
      version = "= 4.10.0"
      source  = "hashicorp/aws"
    }
  }

  required_version = ">= 0.13.1"
  
}
provider "aws" {
    region = "eu-west-1"
    profile = "SolutionArchitect"
    # default_tags {
    #   tags = var.tags
    # }
} 