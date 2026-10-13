# The robot's login username, i.e. what `docker login -u` gets. Surfaced so the caller can print
# it in a plan without digging into Harbor.
output "robot_username" {
  value = harbor_robot_account.forgejo.full_name
}
