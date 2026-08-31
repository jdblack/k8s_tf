variable "plex_name" { default = "plex" }
variable "namespace" { type = string }
variable "movies_pvc" { type = string }
variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "plex_claim" { type = string }

variable "gateway_name" { default = "public" }
variable "gateway_namespace" { default = "kube-network" }
