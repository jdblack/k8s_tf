locals {
  helm_values = {
    seaweedfsFiler = "seaweedfs-filer:8888"
    storageClassName = var.name
    mountService = {
      enabled = true
    }
  }
}
