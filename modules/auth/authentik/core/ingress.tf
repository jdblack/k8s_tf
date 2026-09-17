# This namespace had no policy at all: every pod in the cluster could open a connection to the
# identity database. The guest list is measured (Whisker, `dest_namespace=kube-auth`, 7d, 2026-09-17)
# and it is four peers, three of them the same outpost in three namespaces:
#   * the private gateway's data plane, for `auth.<domain>` on the server pod's :9000 -- post-DNAT, so
#     a rule naming the Service's :80 permits nothing;
#   * the three proxy outposts (`media`, `kube-storage`, `calico-system`), which fetch their config and
#     application lists on that same :9000. Their own egress rules already name this pod, so this call
#     is the other half of that pair.
# Namespace-wide on purpose (`pod_selector` omitted): the worker and the server listen for nothing
# else, and a fourth pod would land outside a pod-scoped selector. The chart's own
# `authentik-postgresql` policy admits :5432 from anything -- Calico unions, so that door stays exactly
# as open as it is today; this call cannot close it and nothing here depends on closing it.
module "ingress" {
  source = "../../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "authentik-ingress"

  from_peers = concat(
    [{
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = local.server_ports
    }],
    # One entry per namespace: a `from` peer ANDs the namespace selector with the pod selector, so the
    # three outposts cannot be expressed as one guest.
    [for ns in var.outpost_namespaces : {
      namespace    = ns
      pod_selector = local.outpost_selector
      ports        = local.server_ports
    }],
  )
}
