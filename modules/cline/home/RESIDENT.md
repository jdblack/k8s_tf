# The resident Cline

A Cline that lives in `cline-home` and remembers through `mempal`. Ships **OFF** (`var.enable_resident`).

## Turn it on
1. Mint the credential Secret — **run this yourself; it never prints your key**:
   `modules/cline/home/make-resident-secret.sh`
2. Enable it, from `stacks/cline-home`: `tofu apply -var enable_resident=true`
3. It currently starts as a placeholder (`cline --version && sleep infinity`). Wiring the actual
   *loop* (what it does unattended) is the next step — see the design note, scheduled one-shots first.

## What is proven (2026-10-14)
- `mempal` answers over the real MCP transport (read + write); `bin/mempal` is the client.
- The image builds and the cluster pulls it; the pod runs; the `subPath` MCP-config mount is correct —
  all tested end-to-end with a dummy Secret, then reverted.

## Traps already paid for
- The npm `cline` CLI package is **3.x**; **4.1.23** is the VS Code *extension*. `cline@4.1.23` is ETARGET.
- A longhorn PVC mounts root-owned: non-root pods need `security_context { fs_group }`.
- The hub is one process / port 25463; don't nest a cline in a cline.

## Do not
- Copy a model credential on someone's behalf. That step belongs to its owner.
