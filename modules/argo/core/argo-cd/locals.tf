locals {
  fqdn = "${var.name}.${var.domain}"
  helm_values = {
    global = {
      domain = local.fqdn
      # Chart >=10.0.0 ships per-component *ingress* NetworkPolicies, on by default; the repo has no
      # ingress for argo yet, so off -- an egress floor (2026-09-17) does not make this true.
      networkPolicy = {
        create = false
      }
    }
    configs = {
      rbac = {
        # Group names must match what oidc_provider creates in authentik (`<app>-admin` /
        # `<app>-user`): with policy.default empty, a name authentik never emits leaves every SSO
        # login with zero permissions. `authentik Admins` gets admin too.
        "policy.csv" = <<-EOF
        g, argo-cd-admin, role:admin
        g, argo-cd-user, role:readonly
        g, authentik Admins, role:admin
        EOF
      }
      # Plain HTTP on 8080, no TLS redirect: the shared private gateway terminates TLS.
      params = {
        "server.insecure" = "true"
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }
      # Chart-native Gateway API route against our ListenerSet; TLS ends at the gateway.
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
