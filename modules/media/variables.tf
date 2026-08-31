variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_authorities" { type = map(any) }
variable "domains" { type = map(any) }

# The media gateway runs in the same namespace as the apps (var.namespace), so
# there is no separate gateway_namespace -- routes/listeners use var.namespace.
variable "gateway_name" { default = "media-private" }
