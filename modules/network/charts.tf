locals {
  charts = {

    metal = {
      name  = "metal"
      url   = "https://metallb.github.io/metallb"
      chart = "metallb"
    },

    ext_dns = {
      name  = "extdns"
      url   = "https://kubernetes-sigs.github.io/external-dns/"
      chart = "external-dns"
    }

  }
}

