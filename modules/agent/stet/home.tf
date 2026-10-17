# THE HOME. Not a scratch volume and not a second brain: this is where a self keeps its FILES —
# the tools it runs, the notes it thinks in, the work it is doing, and one place for the things it
# has not decided about yet.
#
# ★ WHY longhorn RWO AND NOT a RWX filer (measured 2026-10-17): seaweedfs is an S3 gateway wearing a
# POSIX hat — 48x slower per metadata op (339ms vs 7ms for 100 creates), no hardlinks, no xattrs, no
# inotify, best-effort rename durability, and an empty directory of mine VANISHED between two `ls`
# calls. Fine for cold archives; wrong for a home that holds executables and a file watcher.
#
# ★ AND THE RWX REQUIREMENT WAS INVENTED: the brain mounts its own `/data` and never reads this home.
# The only reader is the hand — ONE replica — so a single-writer volume is the honest shape, and it
# keeps real POSIX (atomic rename, inotify, hardlinks) in the boot path. Bells deliberately do not
# mount it: they are ephemeral jobs that run the IMAGE's code and talk to the brain over HTTP, so a
# bell can never depend on this volume or be the reason it needs to be shared.
resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "${var.name}-home"
    namespace = kubernetes_namespace_v1.room.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.home_storage_class

    resources {
      requests = {
        storage = var.home_size
      }
    }
  }

  wait_until_bound = false
}
