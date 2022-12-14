terraform {
    required_version = "~> 1.0"
    required_providers {
       aws = "~> 4.0"
    }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "AuvariaSandboxAdminUser"
}


