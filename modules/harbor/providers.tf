
terraform {
  required_providers {
    harbor = {
      source = "goharbor/harbor"
      version = "3.10.17"
    }
  }
}




#provider harbor {
#  username = "admin"
#  password = random_password.admin_password.result
#  url = local.url
#}
