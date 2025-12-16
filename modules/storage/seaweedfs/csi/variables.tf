variable namespace { type = string }
variable name { default = "seaweedfs" }
variable helm_repo { default = "https://seaweedfs.github.io/seaweedfs-csi-driver/helm" }
variable chart { default = "seaweedfs-csi-driver" }

locals {
  helm_values = {
    seaweedfsFiler = "seaweedfs-filer:8888"
    storageClassName = var.name
    mountService = {
      enabled = true
    }
  }
}
