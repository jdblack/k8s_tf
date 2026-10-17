locals {
  # ★ THE RELEASE IS THE INSTANCE (the self); the WORKLOAD is the object (the anatomy). They differ
  # when an object should say what it is while its labels say whose it is.
  release = coalesce(var.release_name, var.name)

  # The chart derives these from `nameOverride` (`ellmephant`) and the RELEASE name; the firewall
  # policies below have to select on exactly the same pair.
  selector_labels = {
    "app.kubernetes.io/name"     = "ellmephant"
    "app.kubernetes.io/instance" = local.release
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
    #
    # SIZED FROM EVIDENCE, 2026-10-15 (the same lesson as mempal -- modules/cline/home/mem.tf):
    # 4Gi was NOT enough headroom. Prometheus `container_memory_max_usage_bytes` -- an UNSAMPLED
    # cgroup HIGH-WATER MARK, so scrape timing cannot hide a spike -- read 4022.9 MiB against this
    # 4096 MiB limit: ~73 MiB of room, one spike from an OOMKill. The ENCODER is the working set
    # (~2.8-4.0 GiB; `memory.db` is 5 MB), not the store.
    #
    # It matters MORE than it looks: `memory_reembed` CLEARS the vec0 table before rebuilding it, so
    # an OOM mid-reembed leaves the vector index EMPTY (rows are the source of truth, so it is
    # recoverable -- but semantic search silently returns nothing until a clean re-run).
    #
    # CPU is deliberately left unset: this namespace has no LimitRange capping it, and an encoder
    # wants cores. (mempal must set it explicitly -- cline-home's LimitRange would pin it at 250m,
    # "at which point embedding crawls".)
    resources = {
      requests = { cpu = "100m", memory = "1Gi" }
      limits   = { memory = "6Gi" }
    }

    # The store (`memory.db`) is the whole point: without it every memory dies with the pod.
    persistence = {
      enabled      = true
      storageClass = var.storage_class
      size         = var.storage_size
    }

    # Credentials the chart does not know by name: `ELLMEPHANT_IDENTITIES` is a table of
    # `name:secret` pairs, so the values must stay in a Secret rather than in these values.
    env = var.extra_env
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
      hostname         = var.hostname
    }
  } : {}

  helm_values = merge(local.base_values, local.gateway_values)
}
