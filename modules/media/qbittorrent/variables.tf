variable namespace { default = "media" }
variable cert_issuer { type = string }
variable ingress_class { type = string } 
variable domain { type = string }

variable name { default = "qbittorrent" }
variable svc_name { default = "" }

variable web_port { default = 8080 }
variable torrent_port { default = 6887 }


variable movies_pvc { type = string } 

locals {
  svc_name = coalesce(var.svc_name, "${var.name}-svc")
  fqdn = "${var.name}.${var.domain}"
  issuer = var.cert_issuer
  app_data_name  = "${var.name}-data"
}
