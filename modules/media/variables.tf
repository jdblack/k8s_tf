variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_authorities" { type = map(any) }
variable "domains" { type = map(any) }
