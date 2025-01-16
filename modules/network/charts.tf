locals {
  charts = {
    flannel = {
      name = "flannel"
      url = "https://flannel-io.github.io/flannel/"
      chart="flannel"
    }

    metal = {
      name  = "metal"
      url   = "https://metallb.github.io/metallb"
      chart = "metallb"
    },

    ext_dns = {
      name  = "extdns"
      url   = "oci://registry-1.docker.io/bitnamicharts"
      chart = "external-dns"
    }
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

