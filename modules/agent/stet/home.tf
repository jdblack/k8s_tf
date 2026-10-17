# THE HOME. Not a scratch volume and not a second brain: this is where a self keeps its FILES —
# the tools it runs, the notes it thinks in, the work it is doing, and one place for the things it
# has not decided about yet.
#
# ★ WHY RWX (seaweedfs) AND NOT longhorn: the brain and the hand both read this home, and longhorn
# is RWO — two pods on different nodes would fight over the attachment. The home is small, text and
# scripts, so a network filer is the right tool; the DATABASE stays on longhorn, where latency is.
#
# ★ WHY THE LAYOUT IS ENFORCED HERE AND NOT IN PROSE: a home that starts as `~/tmp` and `/tmp/x1`
# becomes 461 unreachable directories in a week. The zones below are the law; see the README the
# copy lays down at the root, whose first line is "nothing lives at the root that is not a zone".
resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "${var.name}-home"
    namespace = kubernetes_namespace_v1.room.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.home_storage_class

    resources {
      requests = {
        storage = var.home_size
      }
    }
  }

  wait_until_bound = false
}
