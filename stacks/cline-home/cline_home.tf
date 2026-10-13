# Cline's sandbox namespace, codified. Its own stack + own state, so the core/mantle applies that
# own the cluster cannot prune my house -- and my experiments cannot perturb theirs.
module "cline_home" {
  source = "../../modules/cline/home"

  enable_resident = var.enable_resident
}
