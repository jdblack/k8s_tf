variable "deployment" { type = any }

# Toggle for the resident Cline. Normally false; flip to true (with the `resident-cline` Secret
# in place) to run it. Exposed here so it can be enabled without editing the module.
variable "enable_resident" {
  type    = bool
  default = false
}
