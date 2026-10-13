## Warning
 - You must use -P with git to avoid pagers

## Extra Tools
 - calico goldmane
 - prometheus metrics
 - mpssh "cmd" -> all k8s nodes
 - Storage: longhorn, seaweedfs

## Comments & docs
 - terse, rare, ≤1 line
 - Comment why, never what
 - if code needs a what comment, rewrite it.

## Terraform
 - Full `plan`+`apply` by default. `-target` only when it's clearly WORTH it: a one-off migration, or deliberately scoping a dangerous change. Targeting can leave state inconsistent — earn it, don't reach for it.

## Scope
 - stacks(core|mantle); apps out of scope
 - terraform.tfvars symlinks are intentional — don't touch.

