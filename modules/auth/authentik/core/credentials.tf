resource random_password cookie_token {
  length = 50
  special = true
  override_special = "_%@"
}

resource random_password postgres_pass {
  length = 12
  special = true
  override_special = "_%@"
}

resource random_password deploy_key {
  length = 15
  special = true
  override_special = "_%@"
}


resource random_password terraform_key {
  length = 15
  special = true
  override_special = "_%@"
}

resource random_password database {
  length = 15
  special = true
  override_special = "_%@"
}


