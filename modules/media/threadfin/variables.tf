variable "namespace" { default = "media" }
variable "cert_issuer" { type = string }
variable "ingress_class" { type = string }
variable "domain" { type = string }
variable "service_port" { default = "34400" }

variable "name" { default = "threadfin" }
variable "svc_name" { default = "" }
