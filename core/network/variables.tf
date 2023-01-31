variable deployment {
  type=map
}

variable namespace {
  type = string 
  default = "network"
}
locals {
  charts = {
    metal = {
      name  = "metal"
      url   = "https://metallb.github.io/metallb" 
      chart = "metallb"
    },
    ext_dns = {
      name  = "extdns"
      url   = "https://charts.bitnami.com/bitnami"
      chart = "external-dns"
    },
    ingress_public = {
      name  = "public"
      url   = "https://kubernetes.github.io/ingress-nginx"
      chart = "ingress-nginx"
    }
    ingress_private = {
      name  = "private"
      url   = "https://kubernetes.github.io/ingress-nginx"
      chart = "ingress-nginx"
    }
  }
}

