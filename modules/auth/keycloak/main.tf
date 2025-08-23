locals {
  domain = "${var.name}.${var.domain}"
  url = "https://${local.domain}"
}


resource "helm_release" "keycloak" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  namespace  = var.namespace

  set  = [
    {
      name = "ingress.enabled"
      value = true
    }, {
      name = "ingress.ingressClassName"
      value = var.ingress_class
    } ,{
      name = "ingress.tls"
      value = true
    } , {
      name = "auth.adminUser"
      value = var.adminuser
    } , {
      name = "auth.adminPassword"
      value = random_password.keycloak_admin.result 
    } , {
      name = "ingress.hostname" 
      value = local.domain
    } , {
      name = "ingress.https"
      value = true
    } , {
      name = "ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
      value = local.domain
    } , {
      name= "ingress.annotations.cert-manager\\.io/cluster-issuer"
      value = var.cert_issuer
    }
  ]

}

output admin_user { value = var.adminuser }
output admin_pass { value = random_password.keycloak_admin.result }
output url        { value = local.url }

