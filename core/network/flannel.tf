

data http flannel_manifest {
  url = var.deployment.flannel.manifest
  request_headers = { Accept = "*" }
}

data kubectl_file_documents flannel {
  content = data.http.flannel_manifest.response_body
}

resource kubectl_manifest flannel {
  for_each  = toset(data.kubectl_file_documents.flannel.documents)
  yaml_body = each.value
  depends_on  = [ kubernetes_namespace.namespace]
}


