locals {
  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"

  # admin.<fqdn> is published by modules/storage/seaweedfs_admin (mantle), behind
  # an authentik outpost -- not here.

  helm_values = {
    global = {
      enableReplication    = true
      replicationPlacement = "001"
      seaweedfs = {
        image = {
          # Registry/name only: the chart's helper reads
          # `default .Chart.AppVersion .Values.image.tag`, so a tag given here is
          # silently ignored -- the tag goes in the top-level `image` block.
          name = "ghcr.io/jdblack/jblack-seaweedfs"
        }
      }
    }

    image = {
      tag = "4.46-gb9e44022c"
    }
    admin = {
      enabled  = true
      grpcPort = "33646"
      # No admin credentials on purpose: leaving admin.secret unset makes the chart
      # omit WEED_ADMIN_USER/WEED_ADMIN_PASSWORD, so the admin API itself is
      # unauthenticated -- access is gated entirely by the authentik outpost.
      #
      # Admin state (task configs, job history, session key) lives under
      # `weed admin -dataDir`, which the chart defaults to emptyDir: without this
      # PVC block the admin silently reverts to defaults on every restart.
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      # The custom 4.46 image added `weed admin -ip`, which defaults to 127.0.0.1
      # and refuses a non-loopback bind unless a password or https.admin mTLS is
      # set -- -allowInsecureBind is what lets -ip=0.0.0.0 through. Neither knob
      # exists on the chart, hence extraArgs.
      #
      # The cost: an unauthenticated admin API on 23646 reachable from
      # kube-storage / kube-network / monitoring (only the gateway path is SSO-gated).
      extraArgs = ["-ip=0.0.0.0", "-allowInsecureBind"]
      ingress = {
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
        enabled = false
      }
    }
  }
}