
resource kubernetes_namespace namespace {
  metadata {
    name = var.namespace
  }
}

locals {
  ca_secret_name = "${var.ssl_ca}.crt"
  helm_values = {
    "externalURL"                = local.url,
    "updateStrategy.type"        = "Recreate",
    "harborAdminPassword"        = random_password.admin_password.result,

    "persistentVolumeClaim.registry.size"  = "20Gi",
    "caBundleSecretName" =  local.ca_secret_name

    "expose.ingress.tls.certSource"        = "secret",
    "expose.ingress.tls.secret.secretName" = "${var.name}-cert",
    "expose.ingress.hosts.core"            = local.fqdn,
    "expose.ingress.className"             = "private",


    "expose.ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname" = local.fqdn,
    "expose.ingress.annotations.cert-manager\\.io/cluster-issuer" = var.certca,

  }
}

resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.namespace

  dynamic "set" {
    for_each = local.helm_values
    content {
      name  = set.key
      value = set.value
    }
  }
}

