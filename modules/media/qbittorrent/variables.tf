variable "namespace" { default = "media" }
variable "domain" { type = string }

variable "name" { default = "qbittorrent" }

variable "web_port" { default = 8080 }
variable "torrent_port" { default = 21010 }

variable "movies_pvc" { type = string }

variable "cert_issuer" { type = string }
variable "gateway_name" { default = "media-private" }
variable "gateway_namespace" { default = "media" }
