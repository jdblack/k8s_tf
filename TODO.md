# TODO

Known issues found during the 2026-08-29 cleanup review.
These are NOT state-preserving fixes - they change deployed behavior, so plan
and review each with `tofu plan` before applying.

## Network

- Systemic: most `helm_release` resources in this repo have no `version`
  pin (cert-manager, prometheus, storage, etc. — the MetalLB release is now
  pinned to `0.16.1`). Any future values/set change will silently upgrade
  those charts to latest. Consider pinning each to the currently-deployed
  chart version.

- `modules/network/firewalls/basic_internet/locals.tf`: the `to_kube_network`
  egress uses `matchlabels` (lowercase) instead of `matchLabels`, so the
  namespaceSelector is silently ineffective whenever `allow_to_services = true`.

## Media

- `modules/media/plex/main.tf`: the helm release `name` is hardcoded to
  `"plex"` instead of using `var.plex_name`. Renaming it now would create a
  second release; only fix together with an import/moved plan.

## Stack overlap

- Namespace `ai` is created by both `stacks/core/ai.tf` and `stacks/apps`
  (via `modules/argo/aoa_deployment` with `ai_create_namespace = true`). The
  same object is claimed by two different state backends. Do not set
  `ai_create_namespace = false` carelessly - removing that resource from
  `stacks/apps` state could delete the whole namespace.
