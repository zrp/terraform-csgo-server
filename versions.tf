terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.56"
    }

    local  = {}
    tls    = {}
    random = {}
  }
}

