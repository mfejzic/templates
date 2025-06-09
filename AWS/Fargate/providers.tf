terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.13.1"
    }
  }
  backend "s3" {
    bucket = "terraform-state-file-mf37" // tf state will be stored here
    key    = "serverless/infra"
    region = "us-east-1"
  }
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}


/*
Switch backend to terraform cloud

backend "remote" {
    hostname     = "app.terraform.io"
    organization = "default-mf"
    workspaces {
      name = "Cloudfront"
    }
  }
  

Swtich to s3 backend

backend "s3" {
    bucket = "terraform-state-file-mf37" // tf state will be stored here
    key    = "web_host/resume/s3_cdn/infra"
    region = "us-east-1"
  }

Switch to local

backend "local" {
    path = "terraform.tfstate"
  }

*/