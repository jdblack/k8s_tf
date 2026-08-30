variable "namespace" { default = "media" }
variable "domain" { type = string }
variable "service_port" { default = "34400" }

variable "name" { default = "threadfin" }
variable "svc_name" { default = "" }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "nginx-gateway" }
