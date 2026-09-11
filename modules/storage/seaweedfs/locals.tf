locals {
  issuer = var.cert_issuers[var.visibility]

  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  admin_host  = "admin.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"

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
      tag = "4.46-gad0032071"
    }
    admin = {
      enabled  = true
      grpcPort = "33646"
      # The chart reads admin credentials from admin.secret.* (userKey/pwKey
      # for an existingSecret, adminUser/adminPassword for a chart-made one).
      # The old top-level adminUser/adminpassword keys are silently ignored,
      # which left the admin API unauthenticated. Putting them under `secret`
      # makes the chart render WEED_ADMIN_USER/WEED_ADMIN_PASSWORD.
      secret = {
        adminUser     = "admin"
        adminPassword = var.admin_password
      }
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
      # admin password (or https.admin mTLS) is set. The chart exposes no
      # admin ipBind (even 4.41.0), so pass it through extraArgs. This only
      # works together with `secret` above -- hence that fix is mandatory.
      extraArgs = ["-ip=0.0.0.0"]
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
