locals {
  fqdn = coalesce(var.fqdn, "${var.name}.${var.domain}")
  helm_values = {
    global = {
      volumeMounts = [
        {
          name      = "cert"
          mountPath = "/certs/${local.fqdn}"
        }
      ]
      volumes = [
        {
          name = "cert"
          secret = {
            secretName = "cert-${local.fqdn}"
          }
        }
      ]
    }
    blueprints = {
      secrets = [
        kubernetes_secret_v1.blueprint_deploy_key.metadata[0].name,
      ]
    }
    authentik = {
      secret_key = random_password.cookie_token.result
      postgresql = {
        password = random_password.postgres_pass.result
      }
    },
    postgresql = {
      enabled = true
      auth = {
        password = random_password.postgres_pass.result
      }
    }
    server = {
      # Chart-native Gateway API route (beta): the chart renders the HTTPRoute
      # against our ListenerSet (NGF only attaches routes to ListenerSet
      # listeners via a ListenerSet parentRef). TLS is terminated at the
      # gateway; the backend is plain HTTP (servicePortHttp).
      route = {
        main = {
          enabled    = true
          hostnames  = [local.fqdn]
          parentRefs = [{
            name        = "auth"
            namespace   = var.namespace
            group       = "gateway.networking.k8s.io"
            kind        = "ListenerSet"
            sectionName = "auth"
          }]
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
          }
        }
      }
    }
  }
}
