variable "namespace" { default = "media" }
variable "movies_pvc" { default = "movies-archive" }
variable "plex_claim" { default = "" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "domains" { type = map(any) }

variable "gateway_name" { default = "media-private" }

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
