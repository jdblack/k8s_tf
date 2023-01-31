locals { 
  nodesdn_yml = {
    _meta = {
      type= "nodesdn"
      config_version= 2
    }
    trustednodes = {
      nodes_dn = [ ] # [ "CN=node*.linuxguru.net" ]
    }
  }
}
