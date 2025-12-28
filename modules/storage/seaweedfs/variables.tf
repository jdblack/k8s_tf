variable namespace { type = string }
variable cert_issuers { type = map }
variable name { default = "seaweedfs" }
variable config_size { default = "1Gi" }
variable helm_repo { default = "https://seaweedfs.github.io/seaweedfs/helm" }
variable chart { default = "seaweedfs" }
variable visibility { default = "private" }

locals {
  sub = var.visibility == "private" ? ".vn" : "" 
  issuer = var.cert_issuers[var.visibility]

  fqdn = "${var.name}${local.sub}.linuxguru.net"
  master_host = "master.${local.fqdn}"
  admin_host = "admin.${local.fqdn}"
  filer_host = "filer.${local.fqdn}"
  s3_host = "s3.vn.linuxguru.net"

  helm_values = {
    global = {
      enableReplication = true
      replicationPlacement = "001"
    }
    admin = {
      enabled = true
      adminUser = "admin"
      adminpassword = "secure"
      ingress = {
        enabled = true
        path = "/"
        host = local.admin_host
        className = var.visibility
        annotations = {
          "cert-manager.io/cluster-issuer" = local.issuer,
          "external-dns.alpha.kubernetes.io/hostname" = local.master_host,
        }
      }
    }

    master = {
      replicas = 1
      data = {
        type = "persistentVolumeClaim"
        size = "2Gi"
        storageClass = ""
      }
      ingress = {
        enabled = true
        path = "/"
        host = local.master_host
        className = var.visibility
        annotations = {
          "cert-manager.io/cluster-issuer" = local.issuer,
          "external-dns.alpha.kubernetes.io/hostname" = local.master_host,
        }
      }
    }
    volume = {
      replicas = 6
      rack = "0"
      dataCenter = "linuxguru-hcmc"
      idx = {
        type = "persistentVolumeClaim"
        size = "2Gi"
        storageClass = ""
      }
      data = {
        type = "hostPath"
        storageClass = ""
        hostPathPrefix = "/ssd"
      }
    }
    filer = {
      replicas = 2
      data = {
        type = "persistentVolumeClaim"
        size = "2Gi"
        storageClass = ""
      }
    }
    worker = {
      enabled = true
      replicas = 1
      capabilities = "vacuum,balance,erasure_coding"
      maxConcurrent = 1
      data = {
        type = "emptyDir"
        hostPathPrefix = "/seaweed-worker"
      }

    }
    s3 = {
      enabled = false
      enableAuth = true
      domain_name = local.s3_host
      host = local.s3_host
      ingress = {
        enabled = true
        className = var.visibility
        host = local.s3_host
        path = "/"
        annotations = {
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0",
          "cert-manager.io/cluster-issuer" = local.issuer,
          "external-dns.alpha.kubernetes.io/hostname" = local.s3_host
        }
      }

    }
  }
}
