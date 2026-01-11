
locals {
  db_name = "valkey-${var.name}"
  config = {
    dataStorage = {
      enabled        = true
      requestedSize  = "1Gi"
      volumeName     = local.db_name
    }
    valkeyConfig = "appendonly yes" 
  }
}

resource "helm_release" "valkey" {
  name       = local.db_name
  repository = "https://valkey.io/valkey-helm/"
  chart      = "valkey"
  namespace  = var.metadata_namespace

  values = [yamlencode(local.config)]
}

