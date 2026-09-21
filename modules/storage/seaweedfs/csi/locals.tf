locals {
  helm_values = {
    seaweedfsFiler   = "seaweedfs-filer:8888"
    storageClassName = var.name
    mountService = {
      enabled = true
    }
    node = {
      # A node DS restart breaks live FUSE mounts in pods, so roll it by hand.
      updateStrategy = { type = "OnDelete" }
    }
  }
}
