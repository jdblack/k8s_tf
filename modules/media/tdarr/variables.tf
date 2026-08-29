variable "namespace" { type = string }
variable "name" { default = "tdarr" }
variable "name_node" { default = "tdarr-node" }

variable "cert_issuer" { type = string }
variable "ingress_class" { type = string }
variable "domain" { type = string }

variable "movies_pvc" { type = string }
