# TODO

Known issues found during the 2026-08-29 cleanup review.
These are NOT state-preserving fixes - they change deployed behavior, so plan
and review each with `tofu plan` before applying.

## Network


- Wireguard installation:  I'm thinking about setting up wireguard so that I
  can vpn while away from home. I had a chat with gemini, which suggested the following:

#stack/core/vpn.tf 
module "wireguard" {
  source = "./modules/vpn/wireguard" # adjust to your module path

  domain    = try(var.deployment.wireguard.domain, var.deployment.openvpn.domain)
  namespace = try(var.deployment.wireguard.namespace, "wireguard-system")
  
  # Optional: pass explicit peers if you want them managed via TF
  peers = ["laptop", "phone"]
}


# modules/network/wireguard/main.tf
resource "helm_release" "wireguard_operator" {
  name             = "wireguard-operator"
  repository       = "https://nccloud.github.io/charts"
  chart            = "wireguard-operator"
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [yamlencode(local.wireguard_operator_helm_values)]
}

resource "kubernetes_manifest" "wireguard_server" {
  manifest = {
    apiVersion = "vpn.wireguard-operator.io/v1alpha1"
    kind       = "Wireguard"
    metadata = {
      name      = var.wireguard_name
      namespace = var.namespace
    }
    spec = {
      mtu                      = "1380"
      enableIpForwardOnPodInit = true
      serviceType              = "LoadBalancer"
      serviceAnnotations = {
        "external-dns.alpha.kubernetes.io/hostname" = var.domain
      }
    }
  }

  depends_on = [helm_release.wireguard_operator]
}

resource "kubernetes_manifest" "wireguard_peers" {
  for_each = toset(var.peers)

  manifest = {
    apiVersion = "vpn.wireguard-operator.io/v1alpha1"
    kind       = "WireguardPeer"
    metadata = {
      name      = each.key
      namespace = var.namespace
    }
    spec = {
      wireguardRef = var.wireguard_name
    }
  }

  depends_on = [kubernetes_manifest.wireguard_server]
}


# modules/network/wireguard/variables.tf
variable "domain" {
  type        = string
  description = "Domain name for external DNS annotation"
}

variable "wireguard_name" {
  type    = string
  default = "wg-server"
}

variable "namespace" {
  type    = string
  default = "wireguard-system"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "peers" {
  type    = list(string)
  default = []
}

locals {
  wireguard_operator_helm_values = {
    nameOverride = "wireguard-operator"
    image = {
      tag        = "latest"
      pullPolicy = "Always"
    }
  }
}











- Systemic: most `helm_release` resources in this repo have no `version`
  pin (cert-manager, prometheus, storage, etc. — the MetalLB release is now
  pinned to `0.16.1`). Any future values/set change will silently upgrade
  those charts to latest. Consider pinning each to the currently-deployed
  chart version.

## Media

- `modules/media/plex/main.tf`: the helm release `name` is hardcoded to
  `"plex"` instead of using `var.plex_name`. Renaming it now would create a
  second release; only fix together with an import/moved plan.

## Stack overlap

- Namespace `ai` is created by both `stacks/core/ai.tf` and `stacks/apps`
  (via `modules/argo/aoa_deployment` with `ai_create_namespace = true`). The
  same object is claimed by two different state backends. Do not set
  `ai_create_namespace = false` carelessly - removing that resource from
  `stacks/apps` state could delete the whole namespace.

