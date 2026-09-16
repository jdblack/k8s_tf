locals {
  fqdn = coalesce(var.fqdn, "${var.name}.${var.domain}")
  # One local so the ListenerSet name and the chart route's parentRef cannot drift
  # apart. Deliberately not var.name.
  listener_name = "auth"
  helm_values = {
    # The chart mounts cert-<fqdn> for the server's own :9443 listener, and its cert
    # discovery task imports whatever it finds there (live: `auth.<domain>` and `ca`, both
    # managed=goauthentik.io/crypto/discovered/...). Nothing routes to :9443 and the OIDC
    # providers no longer depend on the discovered cert (each generates its own signing key
    # in ../oidc_provider), but removing the mount would change both of those behaviours --
    # so it stays.
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
      # Two app-level defaults we have to pin, because the chart stopped setting them and
      # its new defaults are wrong for this cluster:
      #
      #   * 2026.5 changed the default listen IP from 0.0.0.0 to [::]. The chart used to
      #     hardcode AUTHENTIK_LISTEN__{HTTP,HTTPS,METRICS}=0.0.0.0:... and 2026.8.2 sets
      #     none of them, so without this the server would bind the IPv6 wildcard. Calico
      #     here is single-stack IPv4 (assign_ipv6=false) and the Service/route target
      #     9000. (A prior 2026.8 attempt is recorded as crashing the server at startup;
      #     this is the one documented breaking change that matches.)
      #   * 2026.8 only honours X-Forwarded-Proto/-Host/-For from trusted proxies. NGF is
      #     the only hop, so the pod CIDR is the whole list; anything else makes authentik
      #     read HTTPS as HTTP (blocked mixed content, endless loading).
      #
      # trusted_proxy_cidrs stays a comma-joined STRING: the chart flattens nested values
      # into env vars and would render a YAML list as the literal "[10.244.0.0/16]".
      listen = {
        http                = "0.0.0.0:9000"
        https               = "0.0.0.0:9443"
        metrics             = "0.0.0.0:9300"
        trusted_proxy_cidrs = "${var.pod_cidr},127.0.0.1/32"
      }
      # The whole namespace has no internet egress (security.tf). Server and worker both ran
      # a periodic version check against goauthentik.io (the only 443 flows from here), so
      # turn it off rather than let it fail against the firewall.
      disable_update_check = true
      # ...and the startup phone-home, which dials out once per container start.
      disable_startup_analytics = true
    },
    postgresql = {
      enabled = true
      auth = {
        password = random_password.postgres_pass.result
      }
    }
    server = {
      # Chart-native Gateway API route, rendered against our ListenerSet (NGF attaches
      # routes to ListenerSet listeners only via a ListenerSet parentRef). TLS terminates
      # at the gateway; backend is plain HTTP.
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
