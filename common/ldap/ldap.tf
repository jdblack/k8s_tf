locals {
  res_name = "${var.release_name}-openldap"

  values = {
    replicaCount=1
    replication = {
      enabled = "false"
    }
    global = {
      ldapDomain = var.ldap_domain
      adminPassword: random_password.password.result
      configPassword: random_password.password.result
      storageClass = "jiva-rr2"
    }
    env = {
      LDAP_EXTRA_SCHEMAS: "cosine,inetorgperson,nis"
    }
    phpldapadmin = {
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer
        }
        ingressClassName = "private"
        path = "/"
        hosts = [
          "ldap.${var.ldap_domain}"
        ]

        tls = [
          {
            secretName = "openldap-cert"
            hosts = [ "ldap.${var.ldap_domain}" ]

          }
        ]
      }
    }
  }
}


resource "helm_release" "release" {
  name  = var.release_name
  repository = "https://jp-gouin.github.io/helm-openldap/"
  chart = "openldap-stack-ha"

  namespace = var.namespace
  values = [ yamlencode(local.values) ]
}

