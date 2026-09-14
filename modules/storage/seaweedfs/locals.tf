locals {
  issuer = var.cert_issuers[var.visibility]

  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"

  # admin.<fqdn> is published by modules/storage/seaweedfs_admin (mantle), not
  # here -- the admin UI sits behind an authentik outpost.

  helm_values = {
    global = {
      enableReplication    = true
      replicationPlacement = "001"
      seaweedfs = {
        image = {
          # Registry/name only. The tag goes in the top-level `image` block
          # below: the chart's helper reads `default .Chart.AppVersion
          # .Values.image.tag`, so a tag here is silently ignored.
          name = "ghcr.io/jdblack/jblack-seaweedfs"
        }
      }
    }

    # Top-level image overrides -- `tag` is read from HERE.
    image = {
      tag = "4.46-gb9e44022c"
    }
    admin = {
      enabled  = true
      grpcPort = "33646"
      # No admin credentials on purpose: leaving admin.secret unset makes the
      # chart omit WEED_ADMIN_USER/WEED_ADMIN_PASSWORD, so the admin API is
      # itself unauthenticated -- access is gated entirely by the authentik
      # outpost in front of it (modules/storage/seaweedfs_admin).
      # Admin state (task configs, job history, session key) lives under
      # `weed admin -dataDir`; the chart defaults that to emptyDir, so without
      # this PVC block the admin silently reverts to defaults on every restart.
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      # The custom 4.46 image added `weed admin -ip`, which defaults to
      # 127.0.0.1 and refuses a non-loopback bind unless a password or
      # https.admin mTLS is set -- so -allowInsecureBind is what lets it accept
      # -ip=0.0.0.0. Without it the admin refuses to bind and the outpost has
      # nothing to proxy to. Neither knob exists on the chart, hence extraArgs.
      #
      # The cost: an unauthenticated admin API on 23646 to anything that can
      # reach the pod. The namespace ingress firewall admits kube-storage,
      # kube-network and monitoring, so those namespaces can reach it directly
      # (only the gateway path is SSO-gated).
      extraArgs = ["-ip=0.0.0.0", "-allowInsecureBind"]
      ingress = {
        # Handled by the shared private gateway (listeners.tf).
        enabled = false
      }
    }

    master = {
      replicas = 1
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      ingress = {
        # Handled by the shared private gateway (listeners.tf).
        enabled = false
      }
    }
    volume = {
      replicas   = var.volume_replicas
      rack       = "0"
      dataCenter = var.data_center
      data = {
        type           = "hostPath"
        storageClass   = ""
        hostPathPrefix = var.host_path_prefix
      }
    }
    filer = {
      replicas = 1
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
    }
    worker = {
      enabled       = true
      replicas      = var.worker_replicas
      jobType       = "all"
      maxConcurrent = 3
      data = {
        type           = "emptyDir"
        hostPathPrefix = "/seaweed-worker"
      }

    }
    s3 = {
      enabled     = true
      enableAuth  = true
      domain_name = local.s3_host
      host        = local.s3_host
      ingress = {
        # Handled by the shared private gateway (listeners.tf).
        enabled = false
      }
    }
  }
}