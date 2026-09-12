variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_authorities" { type = map(any) }
variable "domains" { type = map(any) }

# The media gateway runs in the same namespace as the apps (var.namespace), so
# there is no separate gateway_namespace -- routes/listeners use var.namespace.
variable "gateway_name" { default = "media-private" }

# Namespace authentik core runs in. The proxy outpost (auth.tf) reaches its API
# there; everything else about the outpost is internal to this module.
variable "auth_namespace" { default = "kube-auth" }

# MetalLB IP the home router port-forwards qbittorrent torrent traffic (21010)
# to. Pinned so the webui/torrent Service split can't reassign it and break the
# port-forward. null lets MetalLB assign automatically.
variable "qbittorrent_torrent_lb_ip" {
  type    = string
  default = null
}

