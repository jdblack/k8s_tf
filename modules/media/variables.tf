variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_authorities" { type = map(any) }
variable "domains" { type = map(any) }

# Per-app cert issuer override, keyed by app name (sonarr / radarr / prowlarr /
# bazarr / qbittorrent). Every app defaults to the public issuer (letsencrypt);
# list one here to put it back on the private CA -- see
# ../cert_manager/README.md.
variable "cert_issuers" {
  type    = map(string)
  default = {}
}

# The media gateway runs in the same namespace as the apps (var.namespace), so
# there is no separate gateway_namespace -- routes/listeners use var.namespace.
variable "gateway_name" { default = "media-private" }

# Namespace authentik core runs in. The proxy outpost (auth.tf) reaches its API
# there; everything else about the outpost is internal to this module.
variable "auth_namespace" { default = "kube-auth" }

# The local LAN, allowed to reach media's LoadBalancers directly -- plex (32400),
# qbittorrent torrent (21010) and the media-private gateway (443). From tfvars.
# Explicit for clarity; the public-internet peer below already covers it. Empty =
# no explicit LAN peer.
variable "lan_cidrs" {
  type    = list(string)
  default = []
}

# The cluster's own pod + service CIDRs, excluded from the public-internet ingress
# peer so every other pod in the cluster stays denied while LAN + internet clients
# (what actually reaches the LoadBalancers) are allowed. From tfvars; the default
# mirrors this cluster (Calico pods 10.244.0.0/16, ClusterIPs 10.96.0.0/12).
variable "cluster_cidrs" {
  type    = list(string)
  default = ["10.244.0.0/16", "10.96.0.0/12"]
}

# MetalLB IP the home router port-forwards qbittorrent torrent traffic (21010)
# to. Pinned so the webui/torrent Service split can't reassign it and break the
# port-forward. null lets MetalLB assign automatically.
variable "qbittorrent_torrent_lb_ip" {
  type    = string
  default = null
}

