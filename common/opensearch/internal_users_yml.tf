locals {
  internal_users_yml = {
    _meta = {
      type = "internalusers"
      config_version= 2
    }
    admin = {
      reserved = true
      hidden = false
      backend_roles = [ "admin" ]
      hash =  random_password.open_pass.bcrypt_hash
    }
  }
}
