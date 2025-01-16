locals {
  domain = "${var.name}.${var.domain}"
  url = "https://${local.domain}"
}


resource "helm_release" "keycloak" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  namespace  = var.namespace

  set {
    name = "ingress.enabled"
    value = true
  }

  set {
    name = "ingress.ingressClassName"
    value = var.ingress_class
  }

  set {
    name = "ingress.tls"
    value = true
  }


  set {
    name = "auth.adminUser"
    value = var.adminuser
  }


  set {
    name = "auth.adminPassword"
    value = random_password.keycloak_admin.result 
  }


  set {
    name = "ingress.hostname" 
    value = var.name
  }

  set {
    name = "ingress.https"
    value = true
  }

  set {
    name = "ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = local.domain
  }

  set {
    name = "ingress.extraHosts[0].name"
    value = local.domain
  }


  set {
    name = "ingress.extraHosts[0].path"
    value = "/"
  }

  set {
    name= "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.cert_issuer
  }

}

output admin_user { value = var.adminuser }
output admin_pass { value = random_password.keycloak_admin.result }
output url        { value = local.url }

