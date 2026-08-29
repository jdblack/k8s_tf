
variable "oauth2_server" {}
variable "namespace" { type = string }
variable "name" { default = "argo-cd" }
variable "deploy_key" { type = string }
variable "repo" { type = string }

variable "domain" {}
variable "cert_issuer" { type = string }
