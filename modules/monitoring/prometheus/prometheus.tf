
resource helm_release prometheus {
  name = var.name
  namespace = var.namespace
  repository = var.repo
  chart = var.chart

  set {
    name = "grafana.enabled"
    value = true
  }

  set {
    name = "grafana.persistence.enabled"
    value = true
  }
 
  set {
    name = "grafana.adminPassword"
    value = "prom-operator"
  }

  set {
    name = "grafana.persistence.size"
    value = "1Gi"
  }

  set {
    name = "grafana.ingress.enabled"
    value = true
  }

  set {
    name = "grafana.ingress.ingressClassName"
    value = "private"
  }


  set {
    name = "grafana.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.cert_issuer
  }


  set_list {
    name = "grafana.ingress.hosts"
    value = [ var.grafana_name, local.grafana.fqdn ]
  }

  set {
    name = "grafana.ingress.tls[0].secretName"
    value = "prometheus-grafana-cert"
  }

  set_list {
    name = "grafana.ingress.tls[0].hosts"
    value = [ var.grafana_name, local.grafana.fqdn ]
  }

}

