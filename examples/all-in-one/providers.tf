terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    port-labs = {
      source  = "port-labs/port-labs"
      version = "2.7.1"
    }
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "your-profile-here"
}

provider "port-labs" {
  client_id = "your-client-id"
  secret    = "your-secret"
}

data "aws_caller_identity" "this" {
  provider = aws
}

data "aws_region" "this" {
  provider = aws
}
