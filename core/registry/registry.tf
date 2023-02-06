resource kubernetes_namespace namespace {
  metadata {
    name = local.namespace
  }
}

locals {
  namespace = coalesce(var.namespace, var.name)
  fqdn = "${var.name}.${var.tld}"
  url = "${local.fqdn}:5000"

  values = yamlencode({
    persistence = {
      enabled = true
      accessMode="ReadWriteOnce"
      storageClass = "jiva-rr2"
    }
    secrets = {
      htpasswd = "${var.docker_user}:${random_password.password.bcrypt_hash}"
    }
    tlsSecretName = module.ssl_cert.secret
    service = {
      type = "LoadBalancer"
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
      }
    }
    updateStrategy = {
      type = "Recreate"
    }
  })
}

resource helm_release release {
  name  = var.name
  repository = var.repository
  chart = var.chart
  namespace = local.namespace
  values = [local.values]
  depends_on = [ kubernetes_namespace.namespace ]
}

