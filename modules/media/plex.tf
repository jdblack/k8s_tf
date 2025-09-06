

# Warning: this is completely broken and does not yet work

variable plex_name { default = "plex" }

locals {
  plex_domain = "${var.plex_name}.linuxguru.net"
  plex_helm_values = {
    "extraEnv.PLEX_UID" = "0",
    "extraEnv.PLEX_GID" = "0",
    "image.tag" = "latest"
    "pullPolicy" = "always"
    "ingress.enabled"   =  true,
    "ingress.ingressClassName" = "public",
    "ingress.url" = local.plex_domain,
    "ingress.hosts.0.paths.0.path"     = "/"
    "ingress.hosts.0.paths.0.pathType" = "ImplementationSpecific",
    "ingress.tls.0.hosts.0"    = local.plex_domain,
    "ingress.tls.0.secretName" = "cert-${local.plex_domain}"
    #"ingress.annotations.cert-manager\\.io/cluster-issuer"  = var.cert_issuer,
    "ingress.annotations.cert-manager\\.io/cluster-issuer"  = "letsencrypt",
    "ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"  = local.plex_domain,
    "extraVolumes[0].name" = "movies-storage",
    "extraVolumes[0].persistentVolumeClaim.claimName" = "movies",
    "extraVolumeMounts[0].name" = "movies-storage",
    "service.type" = "LoadBalancer"
    "extraVolumeMounts[0].mountPath" = "/media/Movies"
  }
}



resource helm_release plex {
  name  = "plex"
  repository = "https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages"
  chart = "plex-media-server"
  namespace = var.namespace
  depends_on = [ kubernetes_namespace.namespace ]
  set = [
    for key, value in local.plex_helm_values : {
      name  = key
      value = value
    }
  ]

}

