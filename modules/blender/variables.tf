variable namespace { default = "blender" }
variable name { default = "blender" }
variable samba_user { default = "jblack" }

locals {
  samba_name = "${var.name}-samba"
  pv_name = "${var.namespace}-${var.name}"
}


