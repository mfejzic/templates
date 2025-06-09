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
    key    = "cloudfront/infra"
    region = "us-east-1"
  }
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
    key    = "cloudnet/infra"
    region = "us-east-1"
  }

Switch to local

backend "local" {
    path = "terraform.tfstate"
  }

*/