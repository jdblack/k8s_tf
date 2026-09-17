locals {
  # Explicit name wins outright; otherwise name_prefix (peer-egress) + a generated 8-hex suffix.
  name_prefix = coalesce(var.name_prefix, "peer-egress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

  # Both mirror `egress`: self on unless turned off, DNS with no knob. Duplicated on a pod that already
  # has a base policy is one redundant rule, not a conflict -- netpols union.
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

  # One rule per peer, so `ports` stays the peer's own. `pod_selector` is merged in only when given: a
  # `to` entry with namespaceSelector AND podSelector is an AND in a single peer.
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

  # Render order: self (unless allow_namespace = false) -> DNS -> peers, in the order given.
  egress = concat(
    local.rule_self != null ? [local.rule_self] : [],
    [local.rule_dns],
    local.rules_peers,
  )
}
