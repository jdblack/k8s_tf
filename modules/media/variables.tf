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

# The local LAN, allowed to reach media's LoadBalancers directly (plex 32400,
# qbittorrent torrent 21010, the media gateway 443).
variable "lan_cidrs" {
  type    = list(string)
  default = []
}

# Excluded from the public-internet ingress peer, so every other pod stays denied while
# LAN + internet clients are allowed. Defaults mirror this cluster (Calico, ClusterIPs).
variable "cluster_cidrs" {
  type    = list(string)
  default = ["10.244.0.0/16", "10.96.0.0/12"]
}

# MetalLB IP to pin the qbittorrent torrent LoadBalancer to. Unset in tfvars: the router
# port-forwards 21010 to that Service, so a re-created Service needs the rule re-pointed
# or this re-pinned -- see qbittorrent/service.tf.
variable "qbittorrent_torrent_lb_ip" {
  type    = string
  default = null
}

