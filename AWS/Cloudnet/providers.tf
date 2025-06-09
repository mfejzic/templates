terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.18.1" 
      
    }
  } 
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}


/*
Switch backend to terraform cloud

backend "remote" {
    hostname     = "app.terraform.io"
    organization = "default-mf"
    workspaces {
      name = "Cloudnet"
    }
  }
  

Swtich to s3 backend

backend "s3" {
    bucket = "terraform-state-file-mf37" // tf state will be stored here
    key    = "cloudnet/infra"
    //region = var.primary_region
  }

Switch to local

backend "local" {
    path = "terraform.tfstate"
  }

*/