terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.73" # aws_glue_catalog federated_catalog; tested with 6.73
    }
  }
}

provider "aws" {
  region = var.region
}
