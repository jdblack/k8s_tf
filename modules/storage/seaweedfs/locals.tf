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
    }
    admin = {
      enabled       = true
      adminUser     = "admin"
      grpcPort      = "33646"
      adminpassword = var.admin_password
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