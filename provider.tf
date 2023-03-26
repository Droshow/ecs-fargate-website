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
  # access_key = var.aws-access-key
  # secret_key = var.aws-secret-key
  region  = "eu-central-1"
  profile = "SolutionArchitect"
}