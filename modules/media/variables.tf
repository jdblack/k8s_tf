variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "domains" { type = map(any) }

# The apps and the gateway share var.namespace, so routes/listeners have no separate
# gateway_namespace.
variable "gateway_name" { default = "media-private" }

variable "auth_namespace" { default = "kube-auth" }

# MetalLB IP to pin the qbittorrent torrent LoadBalancer to. Unset in tfvars: the router
# port-forwards 21010 to that Service, so a re-created Service needs the rule re-pointed
# or this re-pinned -- see qbittorrent/service.tf.
variable "qbittorrent_torrent_lb_ip" {
  type    = string
  default = null
}

