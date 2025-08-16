variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_subnet_cidr2" {
  type    = string
  default = "10.0.3.0/24"
}

variable "environment" {
  description = "enviroment for deployment"
  type        = string
  default     = "_dev"
}

variable "AWS_ACCESS_KEY_ID" {
  type      = string
  sensitive = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  type      = string
  sensitive = true
}

variable "allow_all_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "aws_keypair_name" {
  default = "bastionKP"
}

variable "aws_privatekey_file_name_localmachine" {
  default = "bastionKP.pem"
}