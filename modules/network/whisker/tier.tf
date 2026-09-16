# Calico POLICY-TIER rules, needed since tigera-operator v3.32.2.
#
# The operator's own rules now live in tier `calico-system` (order 100, defaultAction:
# Deny), which is evaluated BEFORE tier `default` -- where every kubernetes_network_policy_v1
# in this module compiles. Its end-of-tier DROP therefore pre-empts all of them, so the three
# k8s policies `whisker-ingress` / `whisker-outpost-egress` / `authentik-outpost-core` are
# still written (they are the portable expression of intent, and become load-bearing again if
# a future operator stops shipping the tier) but are currently UNREACHABLE.
#
# Only a Calico NetworkPolicy CR with `spec.tier` can allow anything in calico-system, so each
# hop the UI needs is re-stated here. These are TIGHTER than the k8s policies they shadow:
# every rule names a pod selector instead of whole namespaces (incl. the gateway hop, which
# was previously unpoliced). Nothing else in the namespace is widened -- the tier's own
# `calico-system.default-deny` still covers everything else.
# See .clinedocs/calico-netpols.md.

locals {
  # Within the tier, policies run lowest-`order`-first and an Allow/Deny ends evaluation, so
  # `10` is what makes these CRs beat the operator's own denies: its holes are `order: 1`
  # (unmatched by our selectors) and `calico-system.default-deny` / `calico-system.whisker`
  # carry NO order, which Felix evaluates last. Any explicitly-set order would do; 10 just
  # groups ours after the operator's.
  tier_policy_order = 10

  tier_outpost_selector = join(" && ", [
    "app.kubernetes.io/name == 'authentik-outpost'",
    "app.kubernetes.io/instance == '${var.outpost_name}'",
  ])

  # Same selector the operator uses for the whisker pods (and the whisker Service).
  tier_whisker_selector = "k8s-app == '${var.whisker_service}'"
}

# 1. Outpost egress: DNS, authentik core, whisker. Shadows `authentik-outpost-core`
#    (from the outpost module) + `whisker-outpost-egress`.
resource "kubectl_manifest" "tier_outpost_egress" {
  yaml_body = yamlencode({
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "whisker-outpost-egress-tier"
      namespace = var.namespace
    }
    spec = {
      # The operator names its tier after the namespace (calico-system).
      tier     = var.namespace
      order    = local.tier_policy_order
      selector = local.tier_outpost_selector
      types    = ["Egress"]

      egress = [
        # DNS, post-DNAT. TCP too: the outpost's resolver retries over TCP.
        {
          action   = "Allow"
          protocol = "UDP"
          destination = {
            namespaceSelector = "projectcalico.org/name == '${var.system_namespace}'"
            selector          = "k8s-app == 'kube-dns'"
            ports             = [53]
          }
        },
        {
          action   = "Allow"
          protocol = "TCP"
          destination = {
            namespaceSelector = "projectcalico.org/name == '${var.system_namespace}'"
            selector          = "k8s-app == 'kube-dns'"
            ports             = [53]
          }
        },
        # authentik core's Service is :80 but Calico evaluates post-DNAT, so the allow
        # names the pod's real HTTP port.
        {
          action   = "Allow"
          protocol = "TCP"
          destination = {
            namespaceSelector = "projectcalico.org/name == '${var.auth_namespace}'"
            selector          = "app.kubernetes.io/name == 'authentik'"
            ports             = [9000]
          }
        },
        # whisker itself (same namespace: no namespaceSelector means "here").
        {
          action   = "Allow"
          protocol = "TCP"
          destination = {
            selector = local.tier_whisker_selector
            ports    = [var.whisker_port]
          }
        },
      ]
    }
  })
}

# 2. Gateway data plane -> outpost:9000. This hop had no policy at all before the tier
#    arrived, so it worked by default; `expose` routes whisker.<domain> here.
#    The outpost's :9443 (https) listener is deliberately left closed -- `expose` uses :9000.
resource "kubectl_manifest" "tier_outpost_ingress" {
  yaml_body = yamlencode({
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "whisker-outpost-ingress-tier"
      namespace = var.namespace
    }
    spec = {
      tier     = var.namespace
      order    = local.tier_policy_order
      selector = local.tier_outpost_selector
      types    = ["Ingress"]

      ingress = [{
        action   = "Allow"
        protocol = "TCP"
        destination = {
          ports = [9000]
        }
        # NGF's data plane pod for this Gateway only (it labels it with the Gateway's
        # name), not the whole kube-network namespace.
        source = {
          namespaceSelector = "projectcalico.org/name == '${var.gateway_namespace}'"
          selector          = "gateway.networking.k8s.io/gateway-name == '${var.gateway_name}'"
        }
      }]
    }
  })
}

# 3. Outpost -> whisker:8081 (same namespace). The operator's `calico-system.whisker` is
#    Ingress+Egress typed with no ingress rules, so nothing could read the UI at all.
resource "kubectl_manifest" "tier_whisker_ingress" {
  yaml_body = yamlencode({
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "whisker-ingress-tier"
      namespace = var.namespace
    }
    spec = {
      tier     = var.namespace
      order    = local.tier_policy_order
      selector = local.tier_whisker_selector
      types    = ["Ingress"]

      ingress = [{
        action   = "Allow"
        protocol = "TCP"
        destination = {
          ports = [var.whisker_port]
        }
        source = {
          selector = local.tier_outpost_selector
        }
      }]
    }
  })
}
