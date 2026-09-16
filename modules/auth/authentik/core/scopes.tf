# The API key Terraform itself uses to manage authentik, deployed as the blueprint Secret the chart
# loads. Deliberately NOT AUTHENTIK_BOOTSTRAP_TOKEN/_PASSWORD: those only feed a once-per-instance
# bootstrap gated on `not Setup.get(tenant=tenant)`, so a running instance ignores them and rotating
# that way means flipping the Setup row by hand.
resource "kubernetes_secret_v1" "blueprint_deploy_key" {
  metadata {
    name      = "${var.name}-tfdeploykey"
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
