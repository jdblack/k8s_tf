locals {
  fqdn = coalesce(var.fqdn, "${var.name}.${var.domain}")
  # The ListenerSet name (and chart route parentRef) is "auth" -- the purpose
  # of authentik is auth, so keep the short name even though var.name is the
  # chart/app name. Derived via local so listener.tf and the chart route can't
  # drift apart.
  listener_name = "auth"
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
          enabled   = true
          hostnames = [local.fqdn]
          parentRefs = [{
            name        = local.listener_name
            namespace   = var.namespace
            group       = "gateway.networking.k8s.io"
            kind        = "ListenerSet"
            sectionName = local.listener_name
          }]
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
          }
        }
      }
    }
  }
}
