# `media`'s egress is a namespace profile plus three pod-scoped exceptions. Everything the
# namespace has in common lives in ONE call; a per-pod call exists only where the profile must not
# hand something to everyone else.
#
#   media-baseline-egress      podSelector: {}   ->  own namespace + DNS + the public internet
#   ngf-egress                 NGF controller       + the API server
#   ngf-cert-generator-egress  NGF hook pod         + the API server
#   authentik-outpost-egress   the outpost          + kube-auth's authentik server, :9000
#
# Stated as rules: the namespace may talk to itself, it may reach the internet, and it is granted
# neither the LAN nor the cluster (no `allow_cluster`, no `to_cidrs`, and no other namespace
# except the outpost's single identity peer on a single port). The gateway is the only thing that
# gets the API server.
#
# Calico unions the rules of every policy selecting a pod, so the first call is a floor and the
# other three only add. Two consequences worth holding on to:
#   - a namespace-wide grant cannot be subtracted from, so **no pod in `media` can be
#     internet-less**. That is the deliberate trade of doing this at the namespace level;
#   - a pod-scoped call that forgets the self rule or DNS is *widened* by the floor rather than
#     narrowed, and silently. Keep `allow_namespace` on and let the floor carry DNS.
#
# Until 2026-09-17 the six apps (sonarr, radarr, prowlarr, bazarr, qbittorrent, plex) and the
# gateway's data plane had calls of their own. All seven rendered self + DNS + internet, i.e.
# exactly what this floor grants, so they were no-ops and were deleted -- the app submodules no
# longer carry an `egress.tf` at all. Their measured notes (post-DNAT ports, the RFC1918
# exclusion, why nothing here needs a storage peer) survive in README.md.

# The namespace profile, and the only call here that is not about one pod. `pod_selector` is
# omitted on purpose: empty renders `podSelector: {}` -- every pod in the namespace, present and
# future, including hand-made ones and helm hook pods. That is what closed the fall-through to
# Kubernetes' default-allow namespace profile (`kns.media`: `egress: [{action: Allow}]` = LAN,
# gateway VIP, API server, internet), which is how the hand-made `utility` pod was getting 200
# from the gateway VIP while every app beside it timed out.
#
# The internet grant is the namespace's: indexers, metadata, notifications, torrent peers and
# plex.tv, on ports that are not predictable, so the public space wholesale. `allow_internet`
# renders 0.0.0.0/0 minus RFC1918 and link-local, and that exclusion is what makes handing it to
# every pod safe: measured from a pod carrying sonarr's labels, the API server, a node, the
# gateway VIP, kube-auth, kube-storage, monitoring and harbor were all unreachable while the
# public space was open (matrix in README.md).
module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace      = var.namespace
  name           = "media-baseline-egress"
  allow_internet = true
}

# NGF control plane: it holds API watches for Gateway API objects. Those are long-lived
# connections, and Whisker never emits those -- so unlike everything else in this file, this peer
# is a construction argument, not an observed flow. Do not read the empty flow log as "no API".
module "egress_ngf" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

# NGF's cert-generator: a `pre-install,pre-upgrade` helm hook that issues the gateway's TLS
# secrets *through the API server*, and a pod no chart label covers -- the chart renders that
# Job's `spec.template` with annotations and no `labels` at all, so the pod carries only
# `job-name=<fullname>-cert-generator` (checked against a live Job pod on this cluster: v1.35 sets
# both `job-name` and `batch.kubernetes.io/job-name`). `ngf-egress` selects the controller's label
# and never covered it, and before the floor existed the hook pod fell through to default-allow --
# the only reason NGF upgrades kept working after the old `allow_api` layer was deleted. Under the
# floor alone the hook dies: measured 2026-09-16, a pod labeled only
# `job-name=ngf-nginx-gateway-fabric-cert-generator` got `rc=28` on `https://10.96.0.1:443/api`
# where a controller-labeled pod got 403. The name comes from the gateway module rather than a
# hardcoded chart internal, so it follows a renamed release.
module "egress_ngf_cert_generator" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-cert-generator-egress"
  pod_selector  = { "job-name" = module.gateway.cert_generator_job_name }
  allow_k8s_api = true
}

# authentik proxy outpost: it validates sessions against the authentik *server* in kube-auth
# (:9000/tcp as observed) and reverse-proxies to the app Services, which the floor already grants
# in this namespace. The identity peer is deliberately one pod selector on one port, where it used
# to be `to_namespaces = [kube-auth]` -- every pod in the identity namespace on every port,
# database and worker included. It is the only cross-namespace grant in `media` and it does not
# need to be any wider than the flow it exists for.
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
