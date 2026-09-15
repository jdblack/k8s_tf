locals {
  fqdn = "${var.name}.${var.domain}"
  helm_values = {
    global = { domain = local.fqdn }
    configs = {
      rbac = {
        # Group names must match what the oidc_provider module creates in authentik
        # (`<app>-admin` / `<app>-user`): with policy.default empty, a name authentik
        # never emits leaves every SSO login with zero permissions. `authentik Admins`
        # (built-in superuser group) gets admin so global admins need not be hand-added
        # per app group.
        "policy.csv" = <<-EOF
        g, argo-cd-admin, role:admin
        g, argo-cd-user, role:readonly
        g, authentik Admins, role:admin
        EOF
      }
      # Plain HTTP on 8080, no TLS redirect: the shared private gateway terminates TLS
      # and proxies to the ClusterIP over HTTP.
      params = {
        "server.insecure" = "true"
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }
      # Chart-native Gateway API route: the chart renders the HTTPRoute against our
      # ListenerSet (NGF only attaches routes to ListenerSet listeners via a
      # ListenerSet parentRef). TLS terminates at the gateway.
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

    finalizers = ["resources-finalizer.argocd.argoproj.io"]
  }
}
