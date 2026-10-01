# A bucket is a filer directory here, so this runs against the cluster rather than a provider.
resource "terraform_data" "bucket" {
  triggers_replace = {
    bucket = var.bucket
    owner  = var.owner
    script = filesha256("${path.module}/provision.sh")
  }

  provisioner "local-exec" {
    command = "sh ${path.module}/provision.sh"

    environment = {
      SEAWEEDFS_NAMESPACE = var.seaweedfs_namespace
      SEAWEEDFS_RELEASE   = var.seaweedfs_release
      SEAWEEDFS_CONTAINER = var.seaweedfs_container
      SEAWEEDFS_MASTER    = var.seaweedfs_master

      BUCKET = var.bucket
      OWNER  = var.owner
    }
  }
}
