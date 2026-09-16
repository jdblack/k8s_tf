locals {
  fqdn = coalesce(var.fqdn, "${var.name}.${var.domain}")
  # One local so the ListenerSet name and the chart route's parentRef cannot drift; not var.name.
  listener_name = "auth"
  helm_values = {
    # Kept though nothing routes to :9443 and no provider depends on the discovered cert any more:
    # removing the mount would change the chart's cert-discovery behaviour and what it imports.
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
      # Both pinned because the chart's new defaults are wrong here: 2026.5 changed the listen IP from
      # 0.0.0.0 to [::] (this cluster is IPv4-only, assign_ipv6=false) and 2026.8 honours X-Forwarded-*
      # only from trusted proxies -- NGF is the only hop, so the pod CIDR is the whole list, and
      # without it authentik reads HTTPS as HTTP (mixed content, endless loading).
      listen = {
        http    = "0.0.0.0:9000"
        https   = "0.0.0.0:9443"
        metrics = "0.0.0.0:9300"
        # Stays a comma-joined STRING: the chart flattens nested values and would render a list
        # as the literal "[10.244.0.0/16]".
        trusted_proxy_cidrs = "${var.pod_cidr},127.0.0.1/32"
      }
      # The namespace has no reason to reach the internet; this kills the goauthentik.io version
      # check, the only 443 flow from here, and the once-per-start startup phone-home.
      disable_update_check      = true
      disable_startup_analytics = true
    },
    postgresql = {
      enabled = true
      auth = {
        password = random_password.postgres_pass.result
      }
    }
    server = {
      # Chart-native Gateway API route, rendered against our ListenerSet: NGF attaches routes to
      # ListenerSet listeners only via a ListenerSet parentRef, and TLS terminates at the gateway.
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
