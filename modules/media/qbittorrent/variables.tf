variable "namespace" { default = "media" }
variable "domain" { type = string }

variable "name" { default = "qbittorrent" }

variable "image" { default = "lscr.io/linuxserver/qbittorrent" }
variable "image_tag" { default = "5.2.3_v2.0.14-ls475" }

variable "web_port" { default = 8080 }
variable "torrent_port" { default = 21010 }

variable "movies_pvc" { type = string }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

variable "auth_backend" { type = string }

variable "torrent_lb_ip" {
  type    = string
  default = null
}
