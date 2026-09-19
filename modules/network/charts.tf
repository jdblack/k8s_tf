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

  helm_values = {
    calico = {
      manageCRDs = true
    }

    external_dns = {
      provider = {
        name = "rfc2136"
      }
      env = [
        {
          name  = "EXTERNAL_DNS_RFC2136_HOST"
          value = local.dns_server
        },
        {
          name  = "EXTERNAL_DNS_RFC2136_PORT"
          value = "53"
        },
        {
          name  = "EXTERNAL_DNS_RFC2136_ZONE"
          value = var.internal_dns.domain
        },
        {
          name  = "EXTERNAL_DNS_RFC2136_TSIG_KEYNAME"
          value = var.internal_dns.client
        },
        {
          name  = "EXTERNAL_DNS_RFC2136_TSIG_SECRET"
          value = var.internal_dns.secret
        },
        {
          name  = "EXTERNAL_DNS_RFC2136_TSIG_SECRET_ALG"
          value = "hmac-sha256"
        }
      ]
      sources                   = ["service", "ingress", "gateway-httproute"]
      policy                    = "upsert-only"
      enableGatewayListenerSets = true
      domainFilters             = [var.internal_dns.domain]
      extraArgs = [
        "--publish-internal-services"
      ]
    }

    metallb = {
      speaker = {
        frr = {
          enabled = false
        }
      }
      frrk8s = {
        enabled = false
      }
    }
  }
}
