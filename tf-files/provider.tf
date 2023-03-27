terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.58.0"
    }
    github = {
      source = "integrations/github"
      version = "5.18.3"
    }
  }
}


provider "aws" {
  region = "us-east-1"
//  access_key = ""
//  secret_key = ""

}

provider "github" {
  token = var.git-token
  }