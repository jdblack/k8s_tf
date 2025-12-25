resource kubernetes_secret_v1 blueprint_deploy_key {
  metadata {
    name = "${var.name}-tfdeploykey"
    namespace = var.namespace
  }
  data = {
    api_key = random_password.terraform_key.result
    "terraform.yaml" = templatefile("${path.module}/api_key.tftpl",
    {
      key = random_password.terraform_key.result
    })
  }
}
