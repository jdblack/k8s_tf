locals {
  name_prefix = coalesce(var.name_prefix, "peer-egress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

  rule_self = var.allow_namespace ? {
    ports = []
    to    = [{ namespace = var.namespace }]
  } : null

  rule_dns = {
    ports = [
      { port = 53, protocol = "UDP" },
      { port = 53, protocol = "TCP" },
    ]
    to = [{
      namespace    = "kube-system"
      pod_selector = { "k8s-app" = "kube-dns" }
    }]
  }

  rules_peers = [
    for peer in var.to_peers : {
      ports = peer.ports
      to = [merge(
        { namespace = peer.namespace },
        peer.pod_selector != null ? { pod_selector = peer.pod_selector } : {},
        length(peer.pod_selector_expressions) > 0 ? { pod_selector_expressions = peer.pod_selector_expressions } : {},
      )]
    }
  ]

  egress = concat(
    local.rule_self != null ? [local.rule_self] : [],
    [local.rule_dns],
    local.rules_peers,
  )
}
