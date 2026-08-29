variable "namespace" { default = "media" }
variable "cert_issuer" { type = string }
variable "ingress_class" { type = string }
variable "domain" { type = string }

variable "name" { default = "qbittorrent" }
variable "svc_name" { default = "" }

variable "web_port" { default = 8080 }
variable "torrent_port" { default = 21010 }


variable "movies_pvc" { type = string }
