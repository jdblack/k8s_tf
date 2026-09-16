# Calico POLICY-TIER rules, needed since tigera-operator v3.32.2.
#
# The operator's own rules live in tier `calico-system` (order 100, defaultAction: Deny),
# which is evaluated BEFORE tier `default` -- where every `kubernetes_network_policy_v1`
# compiles. Its end-of-tier DROP therefore pre-empts ALL k8s NetworkPolicies in this
# namespace, so only a Calico NetworkPolicy CR with `spec.tier` can allow anything here.
#
# THIS IS THE ONLY NETWORK POLICY LEFT IN THIS REPO (the firewalls/ modules and every
# per-app netpol were deleted 2026-09-16). It is kept deliberately: it is not a restriction
# this repo imposes, it is the only thing that lets whisker and its SSO outpost run inside
# `calico-system` at all. Delete these CRs and the operator's own
# `calico-system.default-deny` (selector `k8s-app != 'calico-apiserver'`, no rules) drops
# every flow the outpost needs -- which is exactly how the UI broke on the v3.32.2 upgrade.
# Every rule names a pod selector, so nothing outside these hops is widened.
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
