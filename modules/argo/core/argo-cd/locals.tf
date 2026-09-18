locals {
  fqdn = "${var.name}.${var.domain}"
  helm_values = {
    global = {
      domain = local.fqdn
      networkPolicy = {
        create = false
      }
    }
    configs = {
      rbac = {
        "policy.csv" = <<-EOF
        g, argo-cd-admin, role:admin
        g, argo-cd-user, role:readonly
        g, authentik Admins, role:admin
        EOF
      }
      params = {
        "server.insecure" = "true"
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }
      httproute = {
        enabled   = true
        hostnames = [local.fqdn]
        parentRefs = [{
          name        = var.name
          namespace   = var.namespace
          group       = "gateway.networking.k8s.io"
          kind        = "ListenerSet"
          sectionName = var.name
        }]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
        }
        rules = [{
          matches = [{
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          }]
        }]
      }
    }
  }
}
