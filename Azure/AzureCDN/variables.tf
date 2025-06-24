variable "index" {
  type = string
  default = "index.html"
}
variable "error" {
  type = string
  default = "error.html"
}
variable "default_container" {
  type = string
  default = "$web"
}

variable "uswest" {
  type = string
  default = "westus"
}
variable "useast2" {
  type = string
  default = "eastus2"
}

variable "dev" {
  type = string
  default = "dev"
}