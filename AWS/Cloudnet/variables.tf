variable "primary_region" {
  type = string
  default = "us-east-1"
}

variable "environment" {
  description = "enviroment for deployment"
  type        = string
  default     = "_dev"
}

variable "vpc_cidr" {
  type    = string
  default = "49.0.0.0/16"

}
variable "allow_all_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "public_subnets" {
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
  }
}

variable "private_subnets" {
  default = {
    "private_subnet_1" = 1
    "private_subnet_2" = 2
  }
}

variable "aws_keypair_name" {
  default = "bastionKP"
}

variable "aws_privatekey_file_name_localmachine" {
  default = "bastionKP.pem"
}

variable "bucket_name" {
  default = "mfejzic37"
}



variable "secondary_region" {
  type = string
  default = "us-west-2"
}

variable "environment_sec" {
  description = "enviroment for deployment"
  type        = string
  default     = "_secondary"
}

variable "vpc_cidr_sec" {
  type    = string
  default = "99.0.0.0/16"
}

variable "public_subnets_sec" {
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
  }
}

variable "private_subnets_sec" {
  default = {
    "private_subnet_1" = 1
    "private_subnet_2" = 2
  }
}

variable "aws_keypair_name_sec" {
  default = "bastionKP_sec"
}

variable "aws_privatekey_file_name_localmachine_sec" {
  default = "bastionKP_sec.pem"
}

variable "bucket_name_sec" {
  default = "mfejzic37-secondary"
}



variable "rule_action_allow" {
  type    = string
  default = "allow"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "domain_name" {
  default = "fejzic37.com"
}

variable "subdomain_name" {
  default = "www.fejzic37.com"
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

variable "user_data_script" {
  type    = string
  default = <<-EOF
    #!/bin/bash
    # Install web server software (e.g., Apache)
    sudo apt update -y
    sudo apt install -y apache2
    sudo apt install awscli

    # Fetch index.html from S3 and serve it
    sudo aws s3 cp s3://mfejzic37/host/index.html /var/www/html/
    sudo systemctl start apache2
    sudo systemctl enable apache2
    EOF
}