# The outpost's egress, stated here rather than in `proxy_outpost` for the same reason as `media`'s:
# the module is shared with harbor and the media apps, so a policy inside it would be a policy for
# namespaces it knows nothing about. The namespace profile (`../../storage/egress.tf`) already grants
# this pod its own namespace + DNS, which covers the hop to the admin Service on :23646; what it
# cannot grant is the identity peer.
#
# One pod selector on one port, as measured: `seaweedfs-admin-auth -> authentik-server-...:9000`
# (Whisker, 30-day window -- the namespace's only cross-namespace flow). The Service in front of
# authentik publishes :80 and the outpost dials that, but egress is evaluated POST-DNAT, so the flow
# the policy sees is the server pod's own :9000 and a rule naming 80 would permit nothing
# (`.clinedocs/calico-netpols.md`). `auth_namespace` is the same `kube-auth` variable the provider
# above is built from.
module "egress_outpost" {
  source = "../../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "authentik-outpost-egress"
  pod_selector = { "app.kubernetes.io/name" = "authentik-outpost" }

  to_peers = [{
    namespace    = var.auth_namespace
    pod_selector = { "app.kubernetes.io/name" = "authentik", "app.kubernetes.io/component" = "server" }
    ports        = [{ port = 9000 }]
  }]
}
