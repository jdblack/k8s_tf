locals { 
  roles_mapping_yml = {
    _meta = {
      type= "rolesmapping"
      config_version= 2
    }
    all_access = {
      description= "Maps admin to all_access"
        reserved= true
        backend_roles = [ "admin" ]
    }
    kibana_user = {
      description= "Maps kibanauser to kibana_user"
        reserved= false
        backend_roles= [ "kibanauser" ]
    }
    kibana_server = {
      reserved= true
        users= [ "kibanaserver"]
    }
  }
}
