resource "helm_release" "ntfy" {
  name       = var.name
  namespace  = var.namespace
  repository = "oci://codeberg.org/wrenix/helm-charts"
  chart      = "ntfy"
  version    = "0.5.22"

  values = [yamlencode(local.helm_values)]

  # envFrom references the secret by name *string*, so there is no implicit edge:
  # on a from-scratch build the release could roll a pod before the secret
  # exists, which is a CreateContainerConfigError (envFrom on a missing secret
  # blocks the container). Create the credentials first.
  depends_on = [kubernetes_secret_v1.ntfy_auth]
}
