
resource kubernetes_namespace namespace {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.namespace


  set {
    name = "persistentVolumeClaim.registry.size"
    value = "20Gi"
  }

  set {
    name = "externalURL"
    value = local.url
  }

  set {
    name = "updateStrategy.type"
    value = "Recreate"
  }

  set {
    name = "expose.ingress.tls.certSource"
    value = "secret"
  }

  set {
    name = "expose.ingress.tls.secret.secretName"
    value = "${var.name}-cert"
  }

  set {
    name = "expose.ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = local.fqdn
  }

  set {
    name = "expose.ingress.hosts.core"
    value = local.fqdn
  }

  set {
    name = "expose.ingress.className"
    value = "private"
  }

  set {
    name  = "expose.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.certca
  }

  set {
    name = "harborAdminPassword"
    value = random_password.admin_password.result
  }

  set {
    name = "registry.credentials.username"
    value = "docker"
  }

  set {
    name = "registry.credentials.password"
    value = random_password.registry_password.result
  }

}


output registry_host {  value = local.fqdn }
output registry_url {  value = local.url }
output admin_pass { value = random_password.admin_password.result }
output docker_pass { value = random_password.registry_password.result }
