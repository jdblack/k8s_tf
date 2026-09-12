locals {
  fqdn = "${var.name}.${var.domain}"

  # helm values for the wrenix ntfy chart. That chart renders the server config
  # as NTFY_* env vars (it never writes a server.yml), which is why the auth
  # keys come in through envFrom below rather than through a config file.
  helm_values = {
    ntfy = {
      # Public URL. Needed for generated links (attachments etc.) and to build
      # the web app's own URLs.
      baseURL = "https://${local.fqdn}"

      # ntfy runs behind the NGINX Gateway Fabric data plane, so trust the
      # X-Forwarded-* headers (also what makes per-visitor rate limiting work,
      # instead of lumping every client under the gateway's one IP).
      behindProxy = true

      # deny-all is THE load-bearing setting: ntfy's default is read-write,
      # i.e. every topic world-readable AND world-writable. With deny-all and no
      # ACL entry for the anonymous `*` user, an unauthenticated client gets 403
      # on every subscribe and publish path, and cannot even tell which topics
      # exist.
      auth = {
        file          = "/data/user.db"
        defaultAccess = "deny-all"
      }

      # Persist the message cache so a phone that reconnects after being offline
      # can still fetch the alerts it missed (the default cache is memory-only,
      # so a pod restart drops it).
      cache = {
        file = "/data/cache.db"
      }

      # Web-app account features. Signup stays OFF: nothing on a public endpoint
      # should be able to create accounts, and a self-registered user would be
      # role=user with no access anyway -- a dead end, not a way in.
      enableLogin  = true
      enableSignup = false

      metrics = {
        enable = true
        port   = 9000
      }
    }

    # See variables.tf: without this, a multi-alert Alertmanager payload 400s.
    env = [{
      name  = "NTFY_MESSAGE_SIZE_LIMIT"
      value = var.message_size_limit
    }]

    envFrom = [{
      secretRef = {
        name = kubernetes_secret_v1.ntfy_auth.metadata[0].name
      }
    }]

    # Secret data changes do NOT roll a Deployment (envFrom is only read when the
    # container starts), and the chart's own `confighash` annotation hashes only
    # .Values.ntfy -- not our secret. So without this, a rotated password or
    # token would sit in the Secret unused until some unrelated restart. The
    # annotation puts the credential digest into the pod template, so changing
    # the credentials triggers a rollout.
    podAnnotations = {
      "checksum/ntfy-auth" = local.auth_checksum
    }

    # /data holds user.db (users/ACLs/tokens) and cache.db. Longhorn RWO; the
    # chart already defaults updateStrategy to Recreate, which is what an RWO
    # volume needs (a RollingUpdate that lands the new pod on another node
    # deadlocks on the volume).
    persistence = {
      enabled      = true
      size         = var.storage_size
      storageClass = var.storage_class
    }

    # The ServiceMonitor is created by modules/monitoring/prometheus instead.
    # The chart's own template is gated on
    # .Capabilities.APIVersions.Has "monitoring.coreos.com/v1", so on a
    # from-scratch build (CRD not present when the release is templated) it
    # would be silently skipped and metrics lost.
    prometheus = {
      servicemonitor = {
        enabled = false
      }
    }
  }
}
