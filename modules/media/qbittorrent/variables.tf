variable "namespace" { default = "media" }
variable "domain" { type = string }

variable "name" { default = "qbittorrent" }

variable "web_port" { default = 8080 }
variable "torrent_port" { default = 21010 }

variable "movies_pvc" { type = string }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }

# The authentik outpost Service (same namespace) fronting the web UI; the
# gateway HTTPRoute in route.tf points here. Torrent traffic never touches it.
variable "auth_backend" { type = string }

# MetalLB IP to pin the torrent LoadBalancer Service to. The home router
# port-forwards the torrent port (21010) to this address, so it must not move
# when the Service is re-created by the webui/torrent split. null = auto-assign.
variable "torrent_lb_ip" {
  type    = string
  default = null
}
