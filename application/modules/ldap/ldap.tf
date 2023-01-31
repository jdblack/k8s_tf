locals {
  res_name = "${var.release_name}-openldap"
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

# check out https://github.com/osixia/docker-openldap/issues/105#issuecomment-279673189 

resource "helm_release" "release" {
  name  = var.release_name
  chart = "stable/openldap"
  namespace = var.namespace
  values = [
    templatefile("${path.module}/settings.yaml.tpl", {
      org=var.ldap_org
      domain=var.ldap_domain
    })
  ]

  set {
    name = "persistence.storageClass"
    value = "openebs-jiva-default"
  }

  set {
    name = "service.type"
    value = "LoadBalancer"
  }

  set {
    name = "tls.enabled"
    value = true
  }

  set {
    name = "tls.secret"
    value = module.ssl_cert.secret
  }

}

