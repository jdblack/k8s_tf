
module "blender" {
  source = "../modules/blender"
}

output blender_samba_pass {
  value = module.blender.samba_pass 
  sensitive = true
}



