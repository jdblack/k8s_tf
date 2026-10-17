# THE ROOM. A self = a namespace = a brain + its hands. The labels are what `stacks/` and the fence
# select on, so they are the namespace's identity, not decoration.
resource "kubernetes_namespace_v1" "room" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/part-of" = "agent"
      "agent.linuxguru.net/self"  = var.name
    }
  }
}
