
module "blender" {
  source = "../../modules/blender"
  domain = var.deployment.common.domain
}

output "blender_samba_pass" {
  value     = module.blender.samba_pass
  sensitive = true
}



