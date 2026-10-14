locals {
  # The chart derives these from `nameOverride` (`ellmephant`) and the release name; the firewall
  # policies below have to select on exactly the same pair.
  selector_labels = {
    "app.kubernetes.io/name"     = "ellmephant"
    "app.kubernetes.io/instance" = var.name
  }

  fqdn = "${var.name}.${var.domain}"

  base_values = {
    fullnameOverride = var.name

    image = {
      repository = var.image_repository
      tag        = var.image_tag
      # Half of the constant-tag pair (see `image_tag` in variables.tf): under a MOVING tag the
      # default `IfNotPresent` lets k8s keep the cached image, so a restart appears to deploy while
      # running the old build. `Always` is what makes a restart actually move.
      pullPolicy = "Always"
    }

    # The Qwen3-0.6B embedder cold-load spikes past the chart's 2Gi default, so the first
    # embedding tool call (search/add/update) OOMKills the pod; give it headroom.
    resources = {
      requests = { cpu = "100m", memory = "1Gi" }
      limits   = { memory = "4Gi" }
    }

    # The store (`memory.db`) is the whole point: without it every memory dies with the pod.
    persistence = {
      enabled      = true
      storageClass = var.storage_class
      size         = var.storage_size
    }
  }

  # The chart renders the same ListenerSet + HTTPRoute + ReferenceGrant trio the in-house
  # `network/gateway/expose` module does, so exposure stays a values block, not more resources.
  gateway_values = var.expose ? {
    gateway = {
      enabled          = true
      gatewayName      = var.gateway_name
      gatewayNamespace = var.gateway_namespace
      protocol         = "HTTPS"
      port             = 443
      certIssuer       = var.cert_issuer
      domain           = var.domain
    }
  } : {}

  helm_values = merge(local.base_values, local.gateway_values)
}
