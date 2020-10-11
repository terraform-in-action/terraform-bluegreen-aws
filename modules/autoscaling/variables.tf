variable "ssh_keypair" {
  default = null
  type    = string
}

variable "label" {
  type = string
}

variable "app_version" {
  type = string
}

variable "base" {
  type = any
}
