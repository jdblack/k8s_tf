locals {
  secret_name = var.secret_name != null ? var.secret_name : "${var.user}-s3"
}

# Terraform owns the credential so the Secret and SeaweedFS IAM can never drift; the script only
# pushes what it hands it.
resource "random_password" "access_key" {
  length  = var.access_key_length
  special = false
}

resource "random_password" "secret_key" {
  length  = var.secret_key_length
  special = false
}

resource "terraform_data" "user" {
  triggers_replace = {
    user   = var.user
    bucket = var.bucket
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

      USER   = var.user
      BUCKET = var.bucket
      ROLE   = var.role

      ACCESS_KEY = random_password.access_key.result
      SECRET_KEY = random_password.secret_key.result
    }
  }
}

resource "kubernetes_secret_v1" "credentials" {
  type = "Opaque"

  metadata {
    namespace = var.namespace
    name      = local.secret_name
  }

  data = {
    (var.access_key_key) = random_password.access_key.result
    (var.secret_key_key) = random_password.secret_key.result
  }

  depends_on = [terraform_data.user]
}
