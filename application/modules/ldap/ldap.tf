locals {
  res_name = "${var.release_name}-openldap"

  values = {
    replicaCount=1
    replication = {
      enabled = "false"
    }
    group: "users"
    users: "jblack"
    userPasswords: "admin1"
    global = {
      storageClass = "openebs-jiva-csi-default"
      #      ldapDomain = "vn.linxguru.net"
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

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}


resource "helm_release" "release" {
  name  = var.release_name
  repository = "https://jp-gouin.github.io/helm-openldap/"
  chart = "openldap-stack-ha"

  namespace = var.namespace
  values = [ yamlencode(local.values) ]
}

