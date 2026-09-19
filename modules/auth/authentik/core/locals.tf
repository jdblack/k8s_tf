locals {
  fqdn          = coalesce(var.fqdn, "${var.name}.${var.domain}")
  listener_name = "auth"

  server_ports = [{ port = 9000 }]

  outpost_selector = { "app.kubernetes.io/name" = "authentik-outpost" }
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
      listen = {
        http                = "0.0.0.0:9000"
        https               = "0.0.0.0:9443"
        metrics             = "0.0.0.0:9300"
        trusted_proxy_cidrs = "${var.pod_cidr},127.0.0.1/32"
      }
      disable_update_check      = true
      disable_startup_analytics = true
    },
    postgresql = {
      enabled = true
      auth = {
        password = random_password.postgres_pass.result
      }
      # Velero fs-backup is opt-in per pod volume; `data` is the bitnami postgres volume name.
      primary = {
        podAnnotations = {
          "backup.velero.io/backup-volumes" = "data"
        }
      }
    }
    server = {
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
