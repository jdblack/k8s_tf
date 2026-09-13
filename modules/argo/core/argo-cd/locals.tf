locals {
  fqdn = "${var.name}.${var.domain}"
  helm_values = {
    global = { domain = local.fqdn }
    configs = {
      rbac = {
        # Group names must match what the oidc_provider module creates in
        # authentik -- `<app>-admin` / `<app>-user`, i.e. argo-cd-admin, NOT
        # argocd-admin.  The old `argocd-*` lines matched no group that
        # authentik ever emits, so with policy.default empty every SSO login
        # landed with zero permissions.
        #
        # `authentik Admins` is the built-in superuser group and is granted
        # admin here (as in every other app's group rule) so global admins do
        # not have to be hand-added to each app group.
        "policy.csv" = <<-EOF
        g, argo-cd-admin, role:admin
        g, argo-cd-user, role:readonly
        g, authentik Admins, role:admin
        EOF
      }
      # Serve plain HTTP on 8080 (no TLS redirect): the shared private gateway
      # terminates TLS (linuxguru-ca cert) and proxies to the ClusterIP service
      # over HTTP. Previously the nginx ingress did ssl-passthrough to argo-cd's
      # own TLS. (The chart reads this from the argocd-cmd-params-cm configmap.)
      params = {
        "server.insecure" = "true"
      }
    }

    server = {
      service = {
        type = "ClusterIP"
      }
      # Chart-native Gateway API route (experimental): the chart renders the
      # HTTPRoute against our ListenerSet (NGF only attaches routes to
      # ListenerSet listeners via a ListenerSet parentRef). TLS is terminated
      # at the gateway; the backend is plain HTTP (server.insecure is set via
      # configs.params above, so the chart targets servicePortHttp).
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
