locals {
  oidc_auth = data.kubernetes_secret.oidc.data == null ? {} : {
    grafana = { 
      enabled=true
      adminPassword="admin"
      "grafana.ini" = {
        auth = { 
          generic_oauth = {
            enabled= true
            name="Keycloak"
            allow_sign_up= true
            scopes=  "profile,email,groups"
            auth_url= "https://keycloak.vn.linuxguru.net/realms/linuxguru/protocol/openid-connect/auth"
            token_url= "https://keycloak.vn.linuxguru.net/realms/linuxguru/protocol/openid-connect/token"
            api_url= "https://keycloak.vn.linuxguru.net/realms/linuxguru/protocol/openid-connect/userinfo"
            client_id= data.kubernetes_secret.oidc.data.username
            client_secret= data.kubernetes_secret.oidc.data.password
            role_attribute_path="contains(groups[*], 'grafana-admin') && 'Admin' || contains(groups[*], 'grafana-dev') && 'Editor' || 'Viewer'"
            server = {
              root_url= "http://grafana.vn.linuxguru.net"
            }
          }
        }
      }
    }
  }
  nginx_cfg = {
    grafana = {
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer
        }
        ingressClassName = "private"
        hosts = [ var.domain ]
        tls = [
          {
            secretName = "prometheus-grafana-cert"
            hosts = [ var.domain ]
          }
        ]
      }
    }
  }
  full_cfg = merge(local.nginx_cfg, local.oidc_auth)
}

data "kubernetes_secret" "oidc" {
  metadata {
    namespace = var.oidc_ns
    name = var.oidc_name
  }
}

resource "helm_release" "release" {
  name  = var.release_name
  repository = var.helm_url
  chart = var.chart
  values = [yamlencode(local.full_cfg)]
  namespace = var.namespace

}

