variable "plex_name" { default = "plex" }
variable "namespace" { type = string }
variable "movies_pvc" { type = string }
variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "plex_claim" { type = string }

# plex-media-server chart version. The chart repo (plexinc/pms-docker gh-pages)
# publishes chart 1.9.0 / app 1.43.0 and is pinned here for the same reason as the
# rest: an unpinned chart turns every apply into an implicit upgrade.
variable "helm_version" { default = "1.9.0" }

variable "gateway_name" { default = "public" }
variable "gateway_namespace" { default = "kube-network" }
