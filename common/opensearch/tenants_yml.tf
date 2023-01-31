locals { 
  tenants_yml = {
    _meta = {
      type= "tenants"
      config_version= 2
    }
    admin_tenant = {
      reserved = false
      description= "Demo tenant for admin user"
    }
  }
}
