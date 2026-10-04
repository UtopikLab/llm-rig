# Docker — Host Container Runtime

Host-level container runtime for the `llm-rig` homelab. Docker is a **host
dependency** (used to run GPU-aware images like ComfyUI), not a POC itself — but
it lives in its own folder so the install script and its docs stay next to each
other, matching the repo's per-component layout.

## What it is

Docker Engine (CE) + containerd, used to run containerized workloads such as the
[ComfyUI](../comfyui) image-generation stack. The GPU-aware ComfyUI image mounts
the shared model volume and binds a CUDA device per container — see
[`../comfyui/README.md`](../comfyui/README.md).

## Install

`install-docker.sh` installs Docker Engine on Ubuntu via the **official Docker
procedure** ([docs.docker.com/engine/install/ubuntu](https://docs.docker.com/engine/install/ubuntu/)):

1. Removes any old/broken Docker packages.
2. Adds the official Docker APT repo signed with Docker's GPG key.
3. Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`,
   and `docker-compose-plugin`.
4. Adds the current user to the `docker` group (so Docker runs without `sudo`).
5. Verifies the daemon is running.

```bash
sudo ./install-docker.sh
```

> **After the script finishes, log out and log back in** so your session picks up
> the `docker` group membership. Until then, prefix Docker commands with `sudo`
> (e.g. `sudo docker run hello-world`).

## Verify

```bash
docker run --rm hello-world
```

## Notes

- The socket is `root:docker`, so any user in the `docker` group can run
  containers without `sudo`.
- ComfyUI's GPU-aware image (bind a CUDA device with `--gpus all`) is documented
  in [`../comfyui/README.md`](../comfyui/README.md).
