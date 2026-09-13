locals {
  issuer = var.cert_issuers[var.visibility]

  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"

  # admin.${local.fqdn} is not published here: the admin UI sits behind an
  # authentik proxy outpost owned by modules/storage/seaweedfs_admin (mantle
  # stack -- only mantle has the authentik provider).

  helm_values = {
    global = {
      enableReplication    = true
      replicationPlacement = "001"
      seaweedfs = {
        image = {
          # Registry/name only. The tag lives at the top-level `image` block
          # below: the chart's `seaweedfs.image` helper reads
          # `default .Chart.AppVersion .Values.image.tag`, so a tag placed here
          # is silently ignored and the chart falls back to .Chart.AppVersion.
          name = "ghcr.io/jdblack/jblack-seaweedfs"
        }
      }
    }

    # Top-level image overrides. `tag` is read from here (not from
    # global.seaweedfs.image); registry/repository would also go here.
    image = {
      tag = "4.46-gb9e44022c"
    }
    admin = {
      enabled  = true
      grpcPort = "33646"
      # No app-level admin credentials on purpose: leaving admin.secret unset
      # makes the chart omit WEED_ADMIN_USER/WEED_ADMIN_PASSWORD (and skip the
      # admin Secret), so the admin UI/API is itself unauthenticated. Access is
      # gated entirely by the authentik proxy outpost in front of it
      # (modules/storage/seaweedfs_admin).
      # Admin state (maintenance task configs, plugin/job history, task logs,
      # session key) is written under `weed admin -dataDir`. The chart defaults
      # admin.data.type to "emptyDir", which is wiped on every pod restart -- so
      # without this block the admin silently reverts to defaults on restart
      # (maintenance settings and task configs reset). Pin it to a PVC, exactly
      # like master/filer below, so the configuration survives restarts.
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      # The custom 4.46 image added `weed admin -ip`, which defaults to
      # 127.0.0.1 (loopback only) and refuses a non-loopback bind unless an
      # admin password or https.admin mTLS is set. With the credentials removed
      # above, -allowInsecureBind is what accepts -ip=0.0.0.0 -- WITHOUT it the
      # admin refuses to bind and the outpost has nothing to proxy to. Both go
      # through extraArgs because the chart exposes no ipBind/bind knobs.
      #
      # -allowInsecureBind = an unauthenticated admin API to anything that can
      # reach the pod on 23646. The namespace ingress firewall admits
      # kube-storage (self), kube-network and monitoring, so pods in those
      # namespaces can reach it directly (only the gateway path is SSO-gated).
      extraArgs = ["-ip=0.0.0.0", "-allowInsecureBind"]
      ingress = {
        # Ingress is handled by the shared private gateway (listeners.tf).
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
        # Ingress is handled by the shared private gateway (listeners.tf).
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
        # Ingress is handled by the shared private gateway (listeners.tf).
        enabled = false
      }
    }
  }
}
