variable "domain" { type = string }
variable "name" { default = "harbor" }
variable "oauth2_server" { type = string }

variable "projects" { type = map(any) }
