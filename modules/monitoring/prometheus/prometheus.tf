
resource helm_release prometheus {
  name = var.name
  namespace = var.namespace
  repository = var.repo
  chart = var.chart

  set  = [ 
    {
      name = "grafana.enabled"
      value = true
    } , {
      name = "grafana.persistence.enabled"
      value = true
    } , {
      name = "grafana.adminPassword"
      value = "prom-operator"
    } , {
      name = "grafana.persistence.size"
      value = "1Gi"
    } , {
      name = "grafana.ingress.enabled"
      value = true
    } , {
      name = "grafana.ingress.ingressClassName"
      value = "private"
    } , {
      name = "grafana.ingress.annotations.cert-manager\\.io/cluster-issuer"
      value = var.cert_issuer
    } , {
      name = "grafana.ingress.tls[0].secretName"
      value = "prometheus-grafana-cert"
    } , {
      name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
      value = false
    } , {
      name = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
      value = false
    }
  ]


  set_list = [ 
    {
      name = "grafana.ingress.hosts"
      value = [ var.grafana_name, local.grafana.fqdn ]
    } , {
      name = "grafana.ingress.tls[0].hosts"
      value = [ var.grafana_name, local.grafana.fqdn ]
    }
  ]


}

