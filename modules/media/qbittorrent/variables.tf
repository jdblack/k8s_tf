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

variable "auth_outpost" {
  type = object({
    outpost_id            = string
    service               = string
    port                  = number
    access_token_validity = string
  })
  default     = null
  description = "Gate the app behind this outpost; null routes straight to the app."
}

variable "icon" {
  type        = string
  default     = null
  description = "authentik icon URL; null guesses the dashboard-icons CDN, empty string for no icon."
}

variable "torrent_lb_ip" {
  type    = string
  default = null
}
