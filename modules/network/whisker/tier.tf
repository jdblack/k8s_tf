locals {
  tier_policy_order = 10

  tier_outpost_selector = join(" && ", [
    "app.kubernetes.io/name == 'authentik-outpost'",
    "app.kubernetes.io/instance == '${var.outpost_name}'",
  ])

  tier_whisker_selector = "k8s-app == '${var.whisker_service}'"
}

resource "kubectl_manifest" "tier_outpost_egress" {
  yaml_body = yamlencode({
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "whisker-outpost-egress-tier"
      namespace = var.namespace
    }
    spec = {
      tier     = var.namespace
      order    = local.tier_policy_order
      selector = local.tier_outpost_selector
      types    = ["Egress"]

      egress = [
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
        {
          action   = "Allow"
          protocol = "TCP"
          destination = {
            namespaceSelector = "projectcalico.org/name == '${var.auth_namespace}'"
            selector          = "app.kubernetes.io/name == 'authentik'"
            ports             = [9000]
          }
        },
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
        source = {
          namespaceSelector = "projectcalico.org/name == '${var.gateway_namespace}'"
          selector          = "gateway.networking.k8s.io/gateway-name == '${var.gateway_name}'"
        }
      }]
    }
  })
}

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
