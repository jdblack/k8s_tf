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

  # Helm values for every chart installed by this module (one entry per release:
  # Terraform allows a local name to be declared only once per module, so the
  # releases share the helm_values local and each references its own key).
  helm_values = {
    calico = {}

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
      enableGatewayListenerSets = true
      domainFilters             = [var.internal_dns.domain]
      extraArgs = [
        "--publish-internal-services"
      ]
    }

    metallb = {
      # BGP backend: NATIVE mode (frr disabled, frrk8s disabled). This cluster is
      # L2-only (single IPAddressPool, no BGPPeers), so native is the smallest
      # correct footprint: single-container speaker, no idle FRR sidecars, no
      # frr-k8s controller/CRDs. 0.16.0 deprecated FRR mode in favor of frr-k8s;
      # if BGP is ever needed, switch to frrk8s.enabled = true (the chart default).
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

