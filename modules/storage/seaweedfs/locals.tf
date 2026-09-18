locals {
  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"

  helm_values = {
    global = {
      enableReplication    = true
      replicationPlacement = "001"
      seaweedfs = {
        image = {
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
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
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
      maxConcurrent = 6
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
