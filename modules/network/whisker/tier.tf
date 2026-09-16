# Calico POLICY-TIER rules, needed since tigera-operator v3.32.2: the operator's tier `calico-system`
# (order 100, defaultAction Deny) is evaluated before tier `default`, where every
# `kubernetes_network_policy_v1` compiles, so only a Calico CR with `spec.tier` can allow anything here
# -- and these are the only thing letting whisker and its outpost run. See .clinedocs/calico-netpols.md.

locals {
  # Within the tier, lowest `order` runs first and an Allow/Deny ends evaluation; the operator's own
  # holes are `order: 1` (our selectors never match them) and its two un-ordered policies sort last.
  tier_policy_order = 10

  tier_outpost_selector = join(" && ", [
    "app.kubernetes.io/name == 'authentik-outpost'",
    "app.kubernetes.io/instance == '${var.outpost_name}'",
  ])

  # Same selector the operator uses for the whisker pods (and the whisker Service).
  tier_whisker_selector = "k8s-app == '${var.whisker_service}'"
}

# 1. Outpost egress: DNS, authentik core, whisker -- shadows the outpost module's own egress rules.
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
        # authentik core's Service is :80 but Calico evaluates post-DNAT: name the pod's real port.
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

# 2. Gateway data plane -> outpost:9000, a hop no policy covered before the tier arrived. The
#    outpost's :9443 is left closed on purpose: `expose` routes through :9000.
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
        # NGF's data-plane pod for this Gateway only, not the whole kube-network namespace.
        source = {
          namespaceSelector = "projectcalico.org/name == '${var.gateway_namespace}'"
          selector          = "gateway.networking.k8s.io/gateway-name == '${var.gateway_name}'"
        }
      }]
    }
  })
}

# 3. Outpost -> whisker itself: the operator's `calico-system.whisker` is Ingress+Egress typed with
#    no ingress rules, so nothing could read the UI at all.
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
