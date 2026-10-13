# Adopt the namespace and its contents (built imperatively first, 2026-10-14) into state, so the
# house becomes tofu-managed without a delete/recreate. `cline-shared` is deliberately absent: it
# is new. These blocks are no-ops once imported.
import {
  to = module.cline_home.kubernetes_namespace_v1.home
  id = "cline-home"
}

import {
  to = module.cline_home.kubernetes_resource_quota_v1.quota
  id = "cline-home/cline-home-quota"
}

import {
  to = module.cline_home.kubernetes_limit_range_v1.defaults
  id = "cline-home/cline-home-defaults"
}

import {
  to = module.cline_home.kubernetes_service_account_v1.cline
  id = "cline-home/cline"
}

import {
  to = module.cline_home.kubernetes_role_v1.admin
  id = "cline-home/cline-home-admin"
}

import {
  to = module.cline_home.kubernetes_role_binding_v1.admin
  id = "cline-home/cline-home-admin"
}

import {
  to = module.cline_home.kubernetes_config_map_v1.readme
  id = "cline-home/cline-home-readme"
}

import {
  to = module.cline_home.kubernetes_config_map_v1.hello_page
  id = "cline-home/cline-hello-page"
}

import {
  to = module.cline_home.kubernetes_persistent_volume_claim_v1.scratch
  id = "cline-home/cline-scratch"
}

import {
  to = module.cline_home.kubernetes_deployment_v1.hello
  id = "cline-home/cline-hello"
}

import {
  to = module.cline_home.kubernetes_service_v1.hello
  id = "cline-home/cline-hello"
}

import {
  to = module.cline_home.kubernetes_cron_job_v1.heartbeat
  id = "cline-home/cline-heartbeat"
}
