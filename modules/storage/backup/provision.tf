resource "terraform_data" "provision" {
  triggers_replace = {
    bucket = var.bucket
    user   = var.user
    role   = var.role
    access = random_password.access_key.result
    secret = random_password.secret_key.result
    script = filesha256("${path.module}/provision.sh")
  }

  provisioner "local-exec" {
    command = "sh ${path.module}/provision.sh"

    environment = {
      SEAWEEDFS_NAMESPACE = var.seaweedfs_namespace
      SEAWEEDFS_RELEASE   = var.seaweedfs_release
      SEAWEEDFS_CONTAINER = var.seaweedfs_container
      SEAWEEDFS_MASTER    = var.seaweedfs_master
      BUCKET              = var.bucket
      USER                = var.user
      ROLE                = var.role
      ACCESS_KEY          = random_password.access_key.result
      SECRET_KEY          = random_password.secret_key.result
    }
  }
}
