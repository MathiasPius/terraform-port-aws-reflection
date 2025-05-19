terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 5.0"
    }

    port-labs = {
      source  = "port-labs/port-labs"
      version = "~> 2.7"
    }
  }
}
