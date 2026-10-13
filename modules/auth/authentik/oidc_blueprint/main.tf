resource "tls_private_key" "signing" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "signing" {
  private_key_pem = tls_private_key.signing.private_key_pem
  subject {
    common_name = "${var.name} OIDC signing"
  }
  validity_period_hours = 87600
  allowed_uses          = ["digital_signature"]
}

# ASCII only: the secret is written into a blueprint, and any character YAML would need to escape is a
# chance to disagree with what the client actually sends.
resource "random_password" "client_secret" {
  length  = 64
  special = false
}

# The key must end in .yaml -- the worker globs **/*.yaml, so a Secret keyed `blueprint` mounts and is
# never applied. modules/auth/authentik/core carries the same rule for terraform.yaml.
resource "kubernetes_secret_v1" "blueprint" {
  metadata {
    name      = "${var.name}-blueprint"
    namespace = var.namespace
  }

  data = {
    "${var.name}.yaml" = local.blueprint
  }
}
