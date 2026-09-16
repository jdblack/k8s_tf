locals {
  # Same naming contract as the base builder: an explicit name wins outright, otherwise
  # name_prefix (peer-egress by default) plus a generated 8-hex suffix.
  name_prefix = coalesce(var.name_prefix, "peer-egress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

  # --- no peer list required ---------------------------------------------------------------
  # Both of these mirror `egress`: self on unless the call site turns it off, DNS with no knob
  # at all. Duplicated when the pod already has a base policy -- netpols only union, so a second
  # DNS rule is one redundant rule, not a conflict.
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

  # One rule per peer, so `ports` stays the peer's own. `pod_selector` is added to the peer only
  # when given: a `to` entry with namespaceSelector AND podSelector is an AND in a single peer,
  # which is the shape this builder exists for (namespace + the pods in it + one port).
  rules_peers = [
    for peer in var.to_peers : {
      ports = peer.ports
      to = [merge(
        { namespace = peer.namespace },
        peer.pod_selector != null ? { pod_selector = peer.pod_selector } : {},
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
