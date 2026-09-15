variable "namespace" { default = "media" }
variable "domain" { type = string }

variable "name" { default = "qbittorrent" }

# linuxserver tags read <qbittorrent>_v<libtorrent>-ls<build>. Bump on purpose:
# floating `latest` rolled the torrent client on every pod restart.
variable "image" { default = "lscr.io/linuxserver/qbittorrent" }
variable "image_tag" { default = "5.2.3_v2.0.14-ls475" }

variable "web_port" { default = 8080 }
variable "torrent_port" { default = 21010 }

variable "movies_pvc" { type = string }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

# The authentik outpost Service (same namespace) fronting the web UI.
variable "auth_backend" { type = string }

# MetalLB IP to pin the torrent LoadBalancer Service to; unset by default (see
# service.tf -- the home router port-forwards 21010 to it).
variable "torrent_lb_ip" {
  type    = string
  default = null
}
