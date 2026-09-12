variable "domain" {}
variable "name" { default = "harbor" }
variable "oauth2_server" {}

variable "projects" { type = map(any) }
