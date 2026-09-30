# Local LLM Inference Rig / Promptflow R&D Lab — Architecture Design

> Target hardware: the infra-lab homelab (see [`./HOMELAB-INVENTORY.md`](./HOMELAB-INVENTORY.md)).
> Purpose: Blueprint for a robust, local LLM inference lab with a decoupled, node-based architecture.
> Status: **v1 — operational blueprint.** Subsections marked `_(PENDING)_` map directly to open inventory fields; resolve them in the corresponding rollout phase.

---

## Executive Summary

This lab decouples four concerns onto dedicated machines on the `192.168.1.0/24` subnet:

1. **Heavy inference** → Dell PowerEdge R740xd with 2× Tesla P40 (Pascal, compute 6.1, INT8/DP4A-optimized).
2. **Development** → `DESKTOP-STEEVE` workstations running VS Code + inference-toolkit.
3. **Persistent data & vector storage** → Lenovo ThinkCentre TS430 (ZFS, NFS, Qdrant).
4. **Automation & control plane** → Lenovo M70q (n8n, monitoring, orchestration).

**Hard constraint that governs every decision below:** the Tesla P40 is Pascal (compute 6.1) and performs **extremely poorly on FP16**. All model serving on the R740xd **must** use **INT8 / Q4_K_M / Q8_0 GGUF** via Ollama or `llama.cpp` (DP4A kernels). Do **not** deploy unquantized FP16 models or vLLM FP16/Tensor-Core paths — they will thrash on Pascal.

---

## 1. Architectural Blueprint: Node-by-Node Allocation

| Node | Hardware | Compute | Role | Primary IP (target) |
|------|----------|---------|------|---------------------|
| 1 — Inference Powerhouse | Dell PowerEdge R740xd | 2× Xeon Gold 6148, 96 GB RAM | Centralized LLM inference & heavy execution | `192.168.1.10` |
| 2 — Dev Command Center | DESKTOP-STEEVE | Ryzen 9 5900X, 96 GB RAM, RTX 3080 (10 GB) | Development workstation & light evaluation | DHCP / `192.168.1.50` |
| 3 — Data & Storage Backbone | Lenovo ThinkCentre TS430 | Xeon E3-1280 v2, 31 GB RAM, ZFS RAIDZ1 (~1 TB) | Persistent storage, RAG corpus, eval datasets | `192.168.1.20` |
| 4 — Orchestration & Automation | Lenovo M70q (NUC as spare) | M70q 32 GB RAM, 1 TB SSD | Microservices, tooling, workflow automation | `192.168.1.30` |

> **Note on Node 4.** The inventory also lists a NUC Box (NUC8i5BEK1, 16 GB RAM, 240 GB NVMe) as a separate machine. Reserve it as a spare, VM host, or secondary automation host once the M70q role is settled. See [`./HOMELAB-INVENTORY.md#/pending-questions`](./HOMELAB-INVENTORY.md) for the unresolved CPU/GPU/OS fields.

### 🚀 Node 1: The Inference Powerhouse (Dell PowerEdge R740xd)

- **Assigned Role:** Centralized LLM inference & heavy execution engine.
- **Hardware Utilization:** 2× Intel Xeon Gold 6148 (48C/96T), 96 GB RAM, **2× Tesla P40 (24 GB each, 48 GB total)** — Pascal, compute 6.1.
- **Node 1 Role:** Run **Ollama / llama.cpp** across both P40 GPUs as the high-capacity backend for large open-weights models (Qwen 2.5 Coder 32B, Llama 3.1 70B, etc.) quantized via **INT8 / GGUF**, exposing an **OpenAI-compatible REST API**. Promptflow and inference-rig services route inference here.
- **Lab wiring:** Exposes the OpenAI-compatible endpoint that Nodes 2–4 call for all heavy generation.
- **_(PENDING)_** — chassis serial, room/rack location.

#### Host Hypervisor & Firmware

Node 1 runs **VMware ESXi 8** as its hypervisor (not a bare-metal Ubuntu install). Hardware management is out-of-band via **iDRAC**, and the firmware is at version **16.0.2.3.00.01** (BIOS/HWMON). All guest workloads below are VMs on this hypervisor.

#### Storage Topology

| Tier | Drive | Purpose |
|------|-------|---------|
| **Boot (primary)** | SATA M.2 | ESXi 8 OS boot device |
| **Boot (mirror)** | BOSS-2 card, 2× 256 GB SATA (RAID 1) | Redundant ESXi boot mirror — arriving soon |
| **Hot store** | 1 NVMe 2 TB, on **2× PCIe slots** | VM disks + model cache. Fast random 4K IOPS make NVMe the right substrate for the VM workload |
| _(decided out)_ | 3× SSD 2 TB RAID 5 | **Not purchasing** — the NVMe hot store covers the VM/4K-IOPS need better than a hardware RAID 5 pool |

> 📝 The ESXi boot is mirrored (M.2 + BOSS-2) so a boot-disk failure does not take the whole hypervisor down. The NVMe hot store is where **all VM disks and model weights** live.

#### Virtual Machines

VMs are deployed one-per-purpose on the NVMe hot store. Total host RAM is ~96 GB (physical), with ~48 GB addressable to GPUs via passthrough.

| VM | vCPU | RAM | GPU Passthrough | Storage (recommended) | Suggested OS | Software to install | Role |
|----|------|-----|-----------------|-----------------------|--------------|---------------------|------|
| `pf-host` | 8 | 48 GB | **2× P40** (x16 + x8 slots — both cards) | **256 GB** provisioned on NVMe hot store — includes `llama.cpp` workspace + shared model weights cache | **Ubuntu Server 26.04 LTS** — required for CUDA 13 + NVIDIA P40 driver | **`llama.cpp`** (build + CUDA), NVIDIA P40 driver, CUDA 13; shared model weights (GGUF) + NFS client | Inference host — build via **`llama.cpp-install.sh`**, model weights via **`model-weights.sh`**, CUDA/driver via **`install-cuda.sh`**. | Inference host — serves models with **`llama.cpp` tensor-split across both P40s** (primary, Q8_0/Q4_K_M on `:8080`); Ollama `:11434` optional single-card inference-rig backend. This VM owns the entire GPU pool. |
| `pf-mgmt` | 4 | 16 GB | none | **96 GB** provisioned on NVMe hot store — Promptflow, n8n, workloads | **Ubuntu Server 26.04 LTS** — Python/Promptflow/n8n host | Python 3.12, `promptflow`, n8n (via Docker) | Promptflow, n8n, general dev & orchestration. Routes AI inference to `pf-host`'s endpoint. |
| `grafana` | 2 | 8 GB | none | **24 GB** provisioned on NVMe hot store | **Ubuntu Server 26.04 LTS** (or Grafana's own container image) | Docker Compose (or Grafana image): grafana, node_exporter | Dashboards on :3000 |

> 📝 The 2 TB NVMe hot store is sized so that the 4 VMs above (~600 GB provisioned) leave **~1.4 TB free** for model weights, GGUF caches, NFS-backed datasets, and scratch. Keep at least **30 % free** on the NVMe (≈ 600 GB) for TRIM/over-provisioning and to avoid 4K-IOPS collapse as the pool fills.

> 📝 **Serving runtime — read this before wiring the endpoints.** `pf-host` is the **inference host**. Its **primary GPU path is `llama.cpp`, tensor-split across both P40s** (`--tensor-split 0.5,0.5`, GGUF Q8_0/Q4_K_M, OpenAI-compatible on `:8080`) — that is what serves the large models. **Ollama `:11434` is the optional single-card backend**, kept for inference-rig/Promptflow's `open_ai` connection and quick single-card serving — it does **NOT** split a model across both P40s. So: `llama.cpp` = heavy multi-card inference on `pf-host`; Ollama = optional single-card/inference-rig backend. Both expose OpenAI-compatible APIs. (Details in §2.2–2.3, and per-VM in the OS & Software Matrix below.)

> ⚠️ **One open gate — PCIe passthrough must be confirmed.** Before committing to the VM-per-purpose plan, verify that the Tesla P40s pass through the R740xd's PCIe slots under ESXi 8 (`/dev/vfio`, IOMMA grouping, ACS flags). If passthrough is not viable, the inference VM either runs without GPU or the inference workload runs on the ESXi host OS directly.
>
> **Pre-flight (iDRAC9 firmware 6.x):** the VT-d/IOMMU enable in the BIOS is labeled **"I/O DMA Engine"** (not "Intel VT-d"). Enable it first — this is the passthrough prerequisite, applied on the next (unpowered) reboot:
> 1. iDRAC UI → **Configuration → System → System BIOS → Integrated Devices → I/O DMA Engine → set to `Enabled` → Apply.**
> 2. `racadm` fallback (version-independent): `racadm getcfg -g biosPci -v biosPci.IOMMUEnable` → if not `Enabled`, `racadm config -g biosPci -o biosPci.IOMMUEnable -v Enable` (takes effect on reboot). Note `IOMMUEnterPreOSMode` is pre-OS option-ROM handling (iSCSI), **not** the passthrough enable.
> 3. Pre-reqs already correct: **Memory Mapped I/O above 4GB = `Enabled`**, **Base = 56TB** (required for IOMMU/GPA translation).
> 4. After reboot, confirm in ESXi that each P40 is in its own IOMMU/DMAR group — favorable here since the cards sit on distinct buses (175/216).

> 📝 **Storage & backup note.** The TrueNAS backup appliance in this homelab is a **separate, dedicated** box (not a VM nested inside ESXi), so it adds no guest virtualization overhead and needs no GPU. For VM-side backup and retention, the TS430's **NFS** share is the simplest, preferred default; the external TrueNAS appliance is used as the long-term backup/retention target. If a TrueNAS VM is ever warranted (e.g. whole-lab snapshots), mount it behind the HBA passthrough only after confirming that the extra virtualization overhead is justified.

#### Virtual Machines — OS & Software Matrix

Concrete per-VM OS + install recipe. This is the checklist for building the VMs:

| VM | OS | Software to install | Install note |
|----|----|---------------------|--------------|
| `pf-host` | Ubuntu Server 26.04 LTS | **`llama.cpp`** (built with CUDA 13), NVIDIA P40 driver, CUDA 13; shared GGUF weights on the NVMe/NFS cache; weights via **`model-weights.sh`** | Serve via `llama-server --tensor-split 0.5,0.5 --port 8080` (primary). Ollama `:11434` optional for inference-rig single-card. Build/install order in §3. See §2.2/§2.3/§2.4 |
| `pf-mgmt` | Ubuntu Server 26.04 LTS | Python 3.12, `promptflow`, n8n (Docker), Docker Engine + Compose | Promptflow service + n8n orchestration; point its AI connection at `pf-host` |
| `grafana` | Ubuntu Server 26.04 LTS (or Grafana's container image) | Docker Compose: `grafana`, `node_exporter` | Scrapes `pf-host` (nvidia ddm, Ollama/pf metrics) and Node 4 |

> 📝 **The only VM that touches the GPUs is `pf-host`.** It serves inference with **`llama.cpp` tensor-split across both P40s** (primary, on `:8080`); **Ollama `:11434` is the optional single-card/inference-rig backend** and does **NOT** span both cards. `pf-mgmt` and `grafana` have no GPU passthrough and never see the P40s.

#### Networking

| NIC | Role | Speed |
|-----|------|-------|
| **Intel Gigabit 4P X520/I350 rNDC** (onboard) | Primary lab data network | 1 GbE (shared by all VMs) |
| **TrueNAS (TS430)** | NFS/data traffic | 1 GbE |
| **ConnectX-3 10Gb E SFP+** *(optional add-in card)* | High-bandwidth link to a peer | 10 GbE **only** if a peer (e.g. TS430) also gets 10GbE; otherwise leave unpopulated |

> 📝 The Intel rNDC is gigabit-only. That is **adequate for homelab use** — TS430↔R740xd traffic is backups, archive, and NFS, all low-frequency. A 10Gb E link (ConnectX-3 ~$40–60) is worth adding **only** when a peer node also gets a 10GbE NIC; otherwise gigabit overnight transfers are fine.

### 💻 Node 2: The Developer Command Center (`DESKTOP-STEEVE`)

- **Assigned Role:** Primary development workstation & light evaluation node.
- **Hardware Utilization:** AMD Ryzen 9 5900X, 96 GB RAM, **NVIDIA GeForce RTX 3080 (10 GB VRAM)** — Ampere (compute 8.6), FP16/Tensor-core capable.
- **Node 2 Role:** The day-to-day coding environment. Run **VS Code with the inference-rig Toolkit**, connected via Remote-SSH to the R740xd server (Node 1) or locally. Use the RTX 3080 for quick local debugging, embedding generation, or smaller ultra-fast models (Phi-4, Qwen 2.5 7B) during prompt-engineering iterations. The 3080 is the only FP16-capable GPU in the lab — reserve it for tasks that genuinely benefit from Ampere acceleration.
- **_(PENDING)_** — OS, peripherals, PSU wattage, serial number, daily-driver role.

### 🗄️ Node 3: Data Lake & Vector Storage Backbone (Lenovo ThinkCentre TS430)

- **Assigned Role:** Persistent storage, RAG corpus, & evaluation datasets.
- **Hardware Utilization:** Xeon E3-1280 v2, 31 GB RAM, **ZFS RAIDZ1 Pool (~1 TB)** (3× 931 GB drives).
- **Node 3 Role:** Hosts the local document repositories, training/evaluation datasets for Promptflow evaluation pipelines, and a persistent vector database container (**Qdrant**, exposed on **port 6333**) backing RAG workflows. Serves RAG documents over **NFS** to Node 1.
- **_(PENDING)_** — AIO vs Bay model, OS, serial, pool usage, NFS share definitions.

### ⚙️ Node 4: Orchestration & Automation Control Plane (Lenovo M70q)

- **Assigned Role:** Microservices, tooling, & workflow automation.
- **Hardware Utilization:** Lenovo M70q (32 GB RAM, 1 TB SSD).
- **Node 4 Role:** Runs a lightweight container orchestration layer (**Docker Compose**) hosting infrastructure tooling:
  - **n8n** — automated multi-agent pipelines and webhook triggers (R&D workflows).
  - **AnythingLLM / Open WebUI** — chat interfaces and user-facing testing.
  - **Prometheus + Grafana** — monitoring server temperatures, VRAM usage on the Tesla P40s, and API response latencies (via node_exporter + NVIDIA ddm).
- **_(PENDING)_** — CPU, GPU, OS, serial.

---

## 2. Inference Serving Strategy (P40-Optimized)

### 2.1 Model Quantization & Runtime Rules

| Parameter | Recommended | Rationale |
|-----------|-------------|-----------|
| Precision | **INT8** preferred; **Q8_0** for quality-sensitive; **Q4_K_M** for size-sensitive | Pascal has fast INT8/DP4A paths; FP16 is 5–10× slower on P40 |
| Format | **GGUF** (`gguf`/`q4_k_m`/`q8_0` families) | llama.cpp DP4A kernels target Pascal's INT8 tensor ops |
| Runtime (R740xd) | **llama.cpp** for tensor-split across both P40s; **Ollama** for simple single-card serving | Ollama CUDA backend does NOT split a model across two P40s |
| Runtime (RTX 3080) | FP16 or Q5_K_M acceptable | Ampere (compute 8.6) has Tensor Cores — FP16 is efficient |
| Avoid on P40 | unquantized FP16, vLLM FP16/Tensor-Core paths, FlashAttention-1-only configs | These assume Ampere/Hopper and will thrash |

### 2.2 Tensor-Split Across Both P40s (llama.cpp)

For models too large for a single 24 GB P40, split layers across both cards with CPU offload fallback:

```bash
llama-server \
  --model /mnt/inference-rig/models/qwen2.5-coder-32b-Q4_K_M.gguf \
  --n-gpu-layers 90 \
  --tensor-split 0.5,0.5 \
  --host 192.168.1.10 --port 8080 \
  --ctx-size 8192 --n-proc 8
```

- `-n-gpu-layers` sets how many layers go to GPU (tune upward until VRAM pressure).
- `--tensor-split 0.5,0.5` balances layers across the two P40s.
- Excess layers fall back to CPU RAM (96 GB available) — keep the hot path on GPU.

### 2.3 Ollama Serving (Single-Card, Simplest Path)

`ollama` serves one model per CUDA context; pick the card via `CUDA_VISIBLE_DEVICES`:

```bash
# Serve on P40 in slot 0 only (slot mapping via nvidia-smi order)
CUDA_VISIBLE_DEVICES=0 ollama serve &
ollama run qwen2.5:32b-q4_K_M
```

Expose it OpenAI-compatible (already does so on `:11434`) — Pointflow/inference-rig point at `http://192.168.1.10:11434/v1`.

### 2.4 Promptflow `pf flow serve`

Run the local Promptflow service on the `pf-mgmt` VM (the orchestration host, **not** `pf-host` — `pf-host` reserves `:8080` for `llama.cpp`) and expose the REST API:

```bash
pip install promptflow
pf init --flow ./flows/my-agent-flow
pf flow serve --port 8080 --host <pf-mgmt-ip>
```

Route its `azure_open_ai` / `open_ai` connection to the Ollama endpoint (`http://192.168.1.10:11434/v1`) with `model` set to the GGUF tag. See the note on wiring in §4.

---

## 3. Networking & Storage Layout

### 3.1 IP & DNS Plan (`192.168.1.0/24`)

| Host | Static IP | Notes |
|------|-----------|-------|
| R740xd (Node 1) | `192.168.1.10` | Ollama `:11434`, llama.cpp `:8080` |
| TS430 (Node 3) | `192.168.1.20` | NFS, Qdrant `:6333` |
| M70q (Node 4) | `192.168.1.30` | n8n `:5678`, Grafana `:3000`, Prometheus `:9090` |
| DESKTOP-STEEVE (Node 2) | `192.168.1.50` (or DHCP) | Dev workstations |

> **_(PENDING)_** Confirm these IPs are outside your DHCP pool on the router. Add entries to `/etc/hosts` on every node (or a local Pi-hole/Unbound DNS) so `node1.inference-rig.lan`, `storage.inference-rig.lan`, etc. resolve on the subnet.

### 3.2 NFS Shares (RAG Document Ingestion)

On **Node 3 (TS430)**, export the ZFS pool paths used by Promptflow RAG:

```bash
# /etc/exports on TS430
/tank/inference-rig/documents  192.168.1.0/24(ro,no_subtree_check,all_squash)
/tank/inference-rig/vector_data 192.168.1.0/24(rw,no_subtree_check)
```

Mount on **Node 1 (R740xd)**:

```bash
sudo mkdir -p /mnt/inference-rig/documents /mnt/inference-rig/vector_data
sudo mount -t nfs 192.168.1.20:/tank/inference-rig/documents /mnt/inference-rig/documents
sudo mount -t nfs 192.168.1.20:/tank/inference-rig/vector_data /mnt/inference-rig/vector_data
```

Add persistent mounts in `/etc/fstab` with `_netdev` and `nofail`. Add `/etc/exports` entries as part of Phase 3.

### 3.3 Qdrant (Vector DB)

Qdrant runs on Node 3 (or as a Docker Compose service on Node 4, fronted by NFS for persistence):

- HTTP API: **`192.168.1.20:6333`**
- Persisted under the NFS `vector_data` share so embeddings survive reboots.

---

### 3.1 Inference Stack Bootstrap (pf-host)

After Ubuntu 26.04 LTS is installed and the P40s are visible, bootstrap the inference stack on `pf-host` in this order:

1. **Driver + CUDA:** run `install-cuda.sh` on `pf-host` — installs NVIDIA **620.32.03** driver + **CUDA 13.0.2**. The driver and CUDA versions must match (the package in `install-cuda.sh` pins them together); do **not** mix a different CUDA version with this driver. (matches §3.1 build)
2. **llama.cpp build:** run `llama.cpp-install.sh`. It builds with `-DGGML_CUDA=ON -DGGML_NATIVE=ON -DCMAKE_CUDA_ARCHITECTURES="61" -DLLAMA_OPENSSL=ON` (P40 = sm_61, Pascal, compute 6.1). Do **not** build with `-DLLAMA_CURL=ON` — libcurl support was removed (commit #18828); use **OpenSSL** instead.
3. **Model weights:** run `model-weights.sh` to convert a HuggingFace checkpoint to GGUF and quantize it to Q4_K_M/Q8_0. This enforces the FP16 rule — **no unquantized FP16 or Tensor-Core serving paths**.
4. **Serve:** run `llama-server --model <path> --tensor-split 0.5,0.5 --port 8080` (primary multi-card). Optionally run Ollama on `:11434` for single-card inference-rig calls. See §2.1 for the FP16/runtime rules.

Both `llama.cpp-install.sh` and `model-weights.sh` must be run on `pf-host` (the VM where the P40s and driver live).

#### llama-server as a systemd service

For persistence, install `llama-server` as a systemd service on `pf-host`:

```bash
# llama-server is built into /opt/llama.cpp/bin/ by llama.cpp-install.sh.
# 'install' copies <SOURCE> -> <DEST>/, so point at the real source path:
sudo install -m 0755 /opt/llama.cpp/bin/llama-server /usr/local/bin/
sudo systemctl enable --now llama-server.service
```

If `llama-server.service` doesn't exist after `enable`, add an explicit unit that runs the binary on PATH:

```bash
sudo tee /etc/systemd/system/llama-server.service <<'EOF'
[Unit]
Description=llama.cpp inference server (tensor-split across both P40s)
After=network-online.target

[Service]
ExecStart=/opt/llama.cpp/bin/llama-server --model /mnt/inference-rig/models/qwen2.5-coder-32b-Q4_K_M.gguf --tensor-split 0.5,0.5 --port 8080
Restart=always
RestartSec=5
Environment=CUDA_VISIBLE_DEVICES=

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now llama-server.service
```

`llama-server` splits the two P40s with `--tensor-split 0.5,0.5` and exposes an OpenAI-compatible API on `http://192.168.1.10:8080`. For single-GPU inference-rig calls, run Ollama instead (`see §2.1`) and expose `:11434`.

#### Ollama tension (single-GPU inference-rig)

`install-ollama.sh` installs a single Ollama model onto one P40 (24 GB). A 70B quantized GGUF does not fit on a single P40, so `llama-server` (splitting both GPUs) is the recommended serving path for large models. Use Ollama only for 7B-class GGUFs.

---

## 4. Deployment Phases & Bootstrapping

| Phase | Target Node | Actions | Exit Criteria |
|-------|-------------|---------|---------------|
| **Phase 0** — Hypervisor | R740xd | Install VMware ESXi 8 (mirror boot via SATA M.2 + BOSS-2), configure iDRAC, provision VMs per §2.1 VM list (`pf-host`, `pf-mgmt`, `grafana`). On `pf-host` enable P40 passthrough (or fall back to host OS) and install CUDA 13.0 + driver. | ESXi 8 boots, `nvidia-smi` on `pf-host` shows both P40s (or on host OS if no passthrough) |
| **Phase 1** — Inference VMs | R740xd | Stand up inference VMs: `pf-host` (llama.cpp tensor-split, both P40s); pull a Q4_K_M/Q8_0 model; verify serving. Use `install-cuda.sh` (driver + CUDA 13.0), then `llama.cpp-install.sh` (build), then `model-weights.sh` (weights). | `curl :11434/api/tags` returns model; `curl :8080` responds |
| **Phase 2** — Storage | TS430 | NFS exports for `tank/inference-rig/*`, install & run Qdrant on :6333 | NFS mount works from Node 1; Qdrant health OK |
| **Phase 3** — Orchestration | M70q | Docker Compose: n8n, Grafana, Prometheus, node_exporter | Dashboards scrape all nodes |
| **Phase 4** — Development | DESKTOP-STEEVE | VS Code + inference-toolkit, Remote-SSH to Node 1 | First flow runs against Node 1 inference |
| **Phase 5** — Integrate | All | Wire the `pf-mgmt` Promptflow server → the inference endpoint on pf-host; end-to-end RAG | First multi-agent flow completes |

**Kickstart sequence (minimum to test a multi-agent flow):**

1. **R740xd:** install VMware ESXi 8 (mirror boot via SATA M.2 + BOSS-2) and provision the VMs per §2.1 (Phase 0).
2. **pf-host VM:** enable P40 passthrough (or fall back to host OS) and install CUDA 13.0 + driver (Phase 0).
3. **DESKTOP-STEEVE:** VS Code Remote-SSH → Node 1; author first flow (Phase 4).
4. Wire the flow's AI connection to `http://192.168.1.10:11434/v1` and run.

---

## 5. Security (Zero Trust Per Node)

All control planes must enforce **Zero Trust** — never expose services to `0.0.0.0` on the shared LAN without gating.

- **Bind loopback where possible.** Run services on their management IP, not `0.0.0.0`, and reach them over a VPN or SSH tunnel from dev nodes.
- **Firewall.** Default-deny inbound on every node with `ufw`:
  ```bash
  sudo ufw default deny incoming
  sudo ufw allow from 192.168.1.0/24 to any port 22   # SSH only
  sudo ufw enable
  ```
- **TLS + auth.** Put a reverse proxy (Caddy/Traefik) on Node 4 in front of UIs (Grafana, n8n, WebUI) with auth; Ollama `OLLAMA_ORIGINS` should be restricted to specific dev-node hosts, not `*`.
- **Principle of least privilege.** inference-rig/Ollama run as a dedicated `inference-rig` user, not root; NFS exports `ro`/`all_squash` for documents.
- **_(PENDING)_** Define per-node network zones and a segment firewall policy.

---

## 6. Observability

| Target | Node | Collector | Metric |
|--------|------|-----------|--------|
| NVIDIA GPU telemetry | R740xd | **NVIDIA ddm** (`ddm` collector) | VRAM, temp, utilization, DP4A occupancy |
| Host metrics | All | **node_exporter** (Prometheus) | CPU/RAM/disk/NFS latency |
| API latency | R740xd | Prometheus scrape of Ollama/`pf` metrics | token/s, request duration |
| Dashboards | M70q | **Grafana** on :3000 | all of the above |

- `nvidia-smi` gives a baseline; install the **NVIDIA Datacenter Manager (`ddm`)** for Prometheus-friendly P40 metrics.
- Alert on P40 temp > 85 °C and VRAM > 90 % (Pascal thermal throttles hard).

---

## 7. Backup & Resilience

- **Vector data + documents** on the ZFS pool: rely on ZFS snapshots; additionally schedule a nightly `zfs snapshot` of `tank/inference-rig/*`.
- **Model cache** on R740xd: models are reproducible (re-pull from registry) — no need to back up, but snapshot the GGUF store if retrieval is slow.
- **Node 4 configs** (n8n/Grifana): back up the Docker Compose volume (`/etc/backup`).
- **_(PENDING)_** Define a backup schedule, retention, and an off-site copy for the TS430 pool.

---

## 8. Open Questions (resolve before go-live)

Many map to unresolved inventory fields in `./HOMELAB-INVENTORY.md`:

1. **Node 4 identity** — assign the M70q to the automation plane; repurpose or spare the NUC.
2. **Networking** — link speed between R740xd and `DESKTOP-STEEVE` (GigE vs 10 GbE); fix the P40 serving endpoint on LAN IPs; confirm IPs are outside the DHCP pool.
3. **Storage layout** — TS430 ZFS pool is unallocated; define NFS/SMB shares and the mount plan for `tank/inference-rig/{documents,vector_data}`.
4. **Observability** — Prometheus/Grafana scrape targets; expose P40 telemetry via ddm.
5. **Hardware confirmation** — P40 VRAM (24 GB each per spec; the earlier ADR draft listed 16 GB — confirm driver/nvidia-smi), NVIDIA driver version, and GPU slot→device mapping.
6. **Security** — per-node network zones, TLS/reverse-proxy placement, and firewall policy for the control planes.

---

> **Next step:** which would you like to dive into first — (a) the networking/storage layout between the Dell server and workstation, (b) the P40-optimized Ollama/llama.cpp serving config, or (c) the Docker Compose stack for Node 4? I'll produce the concrete, self-contained scripts/configs for whichever you pick.
