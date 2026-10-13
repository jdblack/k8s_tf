# The robot CI pushes with. Project-scoped to `harbor_project`, and deliberately WITHOUT a
# `duration`: an expiring credential behind a scheduled job is a time bomb that only goes off on
# a day nobody is looking (V-E2 checks `expires_at = -1`).
#
# Permissions are the narrowest set that can publish an image -- repository pull+push, tag
# create+list -- and notably NOT delete. A CI credential has no business being able to remove an
# artifact it just pushed, let alone the whole repository (V-E3).
#
# No `depends_on` on the Harbor project here, on purpose: `library` is Harbor's own default, and
# `module.harbor_setup` owns only `linuxguru` (verified: `deployment.harbor.projects` lists just
# linuxguru, and the state holds a single `harbor_project.project["linuxguru"]`). The old note
# claiming this robot "targets a project harbor_setup creates" was simply wrong (G18-3/P20).
resource "harbor_robot_account" "forgejo" {
  name        = var.robot_name
  description = "Pushes CI-built images from Forgejo Actions."
  level       = "project"
  disable     = false

  permissions {
    kind      = "project"
    namespace = var.harbor_project

    access {
      resource = "repository"
      action   = "pull"
    }
    access {
      resource = "repository"
      action   = "push"
    }
    access {
      resource = "tag"
      action   = "create"
    }
    access {
      resource = "tag"
      action   = "list"
    }
  }
}
