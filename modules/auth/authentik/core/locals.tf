locals {
  fqdn = coalesce(var.fqdn, "${var.name}.${var.domain}")
  # The ListenerSet name and the chart route's parentRef must not drift apart, hence
  # one local. Deliberately not var.name.
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
      # Chart-native Gateway API route: the chart renders the HTTPRoute against our
      # ListenerSet (NGF only attaches routes to ListenerSet listeners via a
      # ListenerSet parentRef). TLS terminates at the gateway; backend is plain HTTP.
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
