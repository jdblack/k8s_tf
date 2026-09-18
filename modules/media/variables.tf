variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "domains" { type = map(any) }

variable "gateway_name" { default = "media-private" }

# NGF version; one of three sites. ngf-public, ngf-private and ngf must all match. CRDs come from modules/network.
variable "helm_ngf_version" {
  default     = "2.7.1"
  description = "nginx-gateway-fabric chart version for this stack's gateway (ngf in namespace media)."
}

variable "auth_namespace" { default = "kube-auth" }

variable "pod_cidr" { type = string }
variable "host_cidr" { type = string }

variable "qbittorrent_torrent_lb_ip" {
  type    = string
  default = null
}

variable "sonarr_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "radarr_api_key" {
  type      = string
  sensitive = true
  default   = ""
}
