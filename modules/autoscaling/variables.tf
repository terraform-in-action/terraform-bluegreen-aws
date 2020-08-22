variable "ssh_keypair" {
  default = null
  type    = string
}

variable "group" {
  type = string
}

variable "app_version" {
  type = string
}

variable "base" {
  type = any
}
