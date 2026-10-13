# resident-cline image

`Dockerfile` builds the resident Cline's image: `node:23-slim` + `npm i -g cline@3.0.71`.

- **Version trap:** the npm CLI package is **3.x**; **4.1.23** is the VS Code *extension*, a different
  artifact. `npm i -g cline@4.1.23` -> `ETARGET`.
- **User trap:** `node:23-slim` already has a uid-1000 `node` user — reuse it, don't `useradd`.

```sh
cd modules/cline/home/image
podman build -t localhost/cline:3.0.71 -f Dockerfile .
podman tag localhost/cline:3.0.71 harbor.vn.linuxguru.net/library/cline:3.0.71
podman push harbor.vn.linuxguru.net/library/cline:3.0.71
```

Built + pushed 2026-10-14; in-cluster pull verified (`cline --version` -> `3.0.71`). Consumed by this
module via `var.resident_image` (the resident Deployment is OFF until a model Secret exists).
