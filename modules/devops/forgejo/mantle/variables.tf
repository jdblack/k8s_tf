# The Harbor project CI images are pushed to. `library` is Harbor's *default* project -- created
# by Harbor itself, not by terraform -- and it is public, so the cluster pulls the pushed images
# anonymously and no imagePullSecret is needed anywhere.
variable "harbor_project" { default = "library" }

# The robot's name. For a project-level robot Harbor renders the login username as
# `robot$<project>+<name>`, so this plus `harbor_project` is exactly what `docker login` wants.
variable "robot_name" { default = "forgejo" }

# Allow-list of Forgejo repositories (`owner/name`) whose Actions get the Harbor credentials.
#
# This is a POLICY list, not something the plan can derive. An EMPTY list creates no secrets --
# safe, but also the integration's silent failure mode: nothing errors, CI simply cannot push.
variable "registry_repos" {
  type = list(string)
}
