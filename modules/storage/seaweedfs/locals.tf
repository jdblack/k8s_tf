locals {
  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"

  # admin.<fqdn> is published by seaweedfs_admin (mantle), behind the outpost.

  helm_values = {
    global = {
      enableReplication    = true
      replicationPlacement = "001"
      seaweedfs = {
        image = {
          # Registry/name only: the chart helper reads AppVersion, so the tag goes in the top-level
          # `image` block below.
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
      # admin.secret unset on purpose: the admin API is then unauthenticated and the outpost is the only
      # gate. The chart defaults -dataDir to emptyDir, so admin state would revert on every restart.
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      # `weed admin -ip` defaults to 127.0.0.1 and refuses a non-loopback bind without a password or
      # mTLS; -allowInsecureBind is what lets -ip=0.0.0.0 through, and neither knob exists on the chart.
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