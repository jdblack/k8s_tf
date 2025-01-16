
resource random_password admin_password {
  length = 15
  special = true
  override_special = "_%@"
}
resource random_password registry_password {
  length = 15
  special = true
  override_special = "_%@"
}


