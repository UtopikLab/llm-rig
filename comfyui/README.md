# ComfyUI — POC

Node-based Stable Diffusion / image-generation stack for the `llm-rig` homelab.

## What it is

ComfyUI is a **node-graph** engine for generative models (text-to-image,
image-to-image, upscaling, video, 3D). Everything is a `node` connected by edges
that pass tensors, and the whole pipeline serializes to a **JSON workflow** you
can version, fork, and reuse. It is the most optimized local diffusion engine
available and is API-first — you can drive it headless from a queue.

### Why ComfyUI over the alternatives

- **Composable graph + JSON workflows** — the pipeline is data you can reuse,
  not a monolithic UI.
- **VRAM / memory efficient** — runs big models on as little as 4 GB VRAM by
  streaming weights and only re-executing the part of the graph that changed.
- **API-first** — scripted generation via REST endpoints; ideal for a batch queue.
- **Broad GPU support** — NVIDIA, AMD, Intel, Apple Silicon, Ascend.
- **Custom nodes** — installable via ComfyUI-Manager.

Alternatives (for reference): **SD-Forge** (faster A1111 drop-in),
**AUTOMATIC1111** (frozen — maintenance only), **InvokeAI** (polished desktop),
**Fooocus** (one-click), **stable-diffusion.cpp / leejet** (zero-Python, portable
— best on CPU/Vulkan), and **diffusers** (pure-Python ML pipelines).

## Hardware fit — the Tesla P40

The 2× Tesla P40 (R740xd) is a **Pascal (compute 6.1)** card: 24 GB each
(48 GB total), CUDA-capable, but **poor on FP16** — Maxwell upconverts fp16 to
fp32, so there is no half-precision speedup.

- ✅ **Huge VRAM** — great for SDXL, batch generation, large resolutions.
- ⚠️ **Run bf16 / fp32**, not fp16. Launch with `--bf16-dtype`.
- ⚠️ **Passive cooling** — no fans. Custom 3D-printed fan mounts or a blower are
  required or it will thermal-throttle.
- ⚠️ **Headless compute** — no video outputs; access over the network.
- 💡 For single-image latency, an RTX 3080 (Ampere, Node 2) is far faster. The
  P40 wins on **throughput / batch**, not per-image speed.

**Recommendation:** run **one ComfyUI instance per P40**, each bound to a CUDA
device, and split a batch queue between them.

## Installation

### Prerequisites

- NVIDIA driver + CUDA (see [`../driver/install-cuda.sh`](../driver/install-cuda.sh)).
- Python 3.12 (3.13 works; 3.14 may break some custom nodes).
- PyTorch with CUDA 13.0+:

```bash
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
```

### pip install

```bash
git clone https://github.com/Comfy-Org/ComfyUI
cd ComfyUI
pip install -r requirements.txt
```

### Run (P40-tuned)

```bash
python main.py --bf16-dtype --lowvram --enable-manager
```

| Flag | Why |
|------|-----|
| `--bf16-dtype` | P40 handles bf16 better than fp16 (no fp16 speedup on Pascal). |
| `--lowvram` / `--novram` | Controls GPU/RAM offloading — tune to your VM memory. |
| `--enable-manager` | Enables ComfyUI-Manager (custom nodes). |

Access the UI at `http://127.0.0.1:8188`.

### Model placement

```
ComfyUI/models/
├── checkpoints/   *.safetensors, *.ckpt
├── vae/
├── loras/
├── clip/
└── embeddings/
```

### Headless / batch

ComfyUI exposes REST endpoints (see `api_server/`). Queue jobs and pull outputs
programmatically so a scheduler can fan work across both P40s.

## Docker (optional)

Docker Engine is installed on the host via [`../docker/`](../docker/)
(`install-docker.sh`). A GPU-aware image keeps the host clean — mount the shared
model volume and bind a CUDA device per container.

```bash
docker run -it --rm --gpus all \
  -v "$(pwd)/models:/root/comfyui/models" \
  -p 8188:8188 \
  comfyorg/comfyui:latest \
  python main.py --bf16-dtype --lowvram
```

## Notes

- Run `--offline` to disable optional paid Comfy API partner nodes.
- High-quality previews: drop TAESD decoders into `models/vae_approx` and launch
  with `--preview-method taesd`.
- Share models between UIs via `extra_model_paths.yaml`.
