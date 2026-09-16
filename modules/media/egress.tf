# One namespace profile (`podSelector: {}`) plus three pod-scoped exceptions: Calico unions them, so
# the floor is added to, never restated, and a per-pod call exists only where the floor must not hand
# something to everyone else.

# Namespace profile: `pod_selector` omitted on purpose, so it covers every pod present and future --
# what closed the fall-through that let the hand-made `utility` pod reach the gateway VIP.

# The internet grant is the namespace's -- indexers, metadata, notifications, torrent peers, plex.tv
# on unpredictable ports -- and RFC1918 staying excluded is what makes it safe handed to every pod.
module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace      = var.namespace
  name           = "media-baseline-egress"
  allow_internet = true
}

# NGF control plane: API watches on long-lived connections, which Whisker never emits -- a
# construction argument, not an observed flow, so an empty log here does not mean "no API".
module "egress_ngf" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

# NGF's cert-generator hook pod: the chart's Job template sets no pod labels, so only `job-name`
# matches it -- and the name comes from the gateway module, so it follows a renamed release.
module "egress_ngf_cert_generator" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-cert-generator-egress"
  pod_selector  = { "job-name" = module.gateway.cert_generator_job_name }
  allow_k8s_api = true
}

# The outpost's one identity peer: a pod selector on a single port, where it used to be
# `to_namespaces = [kube-auth]` -- every pod there, database and worker included.
module "egress_outpost" {
  source = "../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "authentik-outpost-egress"
  pod_selector = { "app.kubernetes.io/name" = "authentik-outpost" }

  to_peers = [{
    namespace    = var.auth_namespace
    pod_selector = { "app.kubernetes.io/name" = "authentik", "app.kubernetes.io/component" = "server" }
    ports        = [{ port = 9000 }]
  }]
}
