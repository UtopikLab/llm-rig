# llm-rig

Homelab **LLM & image-tool POC repository** for the `192.168.1.0/24` subnet.
This repo holds proof-of-concept setups for local LLM tooling — grouped by POC,
each with its own folder and its own README for documentation.

It focuses on the **local inference/image stack only**. It does **not** document
the other three homelab nodes (Development Command Center, Data Backbone,
Orchestration/Promptflow) — those live in `foundry-rig/` and `infra-lab/`.

## POC Inventory

| POC | What it is | Stack | Docs |
|-----|-----------|-------|------|
| **Node 1 — Inference Rig** | 2× Tesla P40 (R740xd) local LLM inference | llama.cpp (`GGML_CUDA`) + Ollama, GGUF `q8_0`/`q4_k_m` | scripts [`driver/`](driver), [`llama-cpp/`](llama-cpp), [`ollama/`](ollama), [`models/`](models) |
| **ComfyUI** | Node-based Stable Diffusion / image generation | ComfyUI (Docker or pip), PyTorch | doc [`comfyui/README.md`](comfyui/README.md) · scripts [`comfyui/`](comfyui) |
| **Docker** | Host container runtime (runs GPU-aware images) | Docker Engine (CE) + containerd | doc [`docker/README.md`](docker/README.md) · scripts [`docker/`](docker) |

> **P40 note.** The Tesla P40 is Pascal (compute 6.1) — CUDA-capable but poor on
> FP16. All lab LLM models are served as GGUF INT8/Q4_K_M; image generation runs
> best on the RTX 3080 (Node 2, Ampere) or CPU. See [`comfyui/README.md`](comfyui/README.md).

## Repo layout

```
llm-rig/
├── README.md                       # this file — root overview + POC inventory
├── driver/                         # install-cuda.sh (NVIDIA driver + CUDA 13)
├── llama-cpp/                      # llama.cpp-install.sh (CUDA build)
├── ollama/                         # install-ollama.sh
├── models/                         # downloaded GGUF weights (model-weights.sh)
├── docker/                         # install-docker.sh (host container runtime)
├── comfyui/                        # ComfyUI POC (image generation)
│   ├── README.md                   # ComfyUI POC doc (hardware fit, install)
│   ├── scripts/                    # ComfyUI install/deploy scripts
│   └── models/                     # downloaded checkpoints / pipelines
└── .gitignore
```

**Layout rules** — this is a **multi-POC repo**: each topic lives in its own
folder, with its own README as the documentation for that folder. There is **no**
shared `docs/` directory (see [`.copilot-instructions.md`](.copilot-instructions.md)).

- **Scripts grouped by component** at the repo root — `driver/`, `llama-cpp/`,
  `ollama/`, and `models/` for the Node 1 rig; `docker/` for the host container
  runtime; `comfyui/` for image-gen scripts.
- **Each POC keeps its own README** — the documentation for a POC lives next to
  its scripts, not in a centralized docs folder.
- **Adding a new POC** is a one-page pattern: create a folder at the repo root
  for its scripts (grouped by component) and a `models/` folder for downloads,
  plus a `README.md` for its documentation, then list it in the POC inventory
  above.

## Contributing
Each POC lives at the repo root as its own folder, with its own README.
Keep scripts grouped by component.
New POCs follow the pattern above and are added to the POC inventory.

## Related

- Full 4-node blueprint: `foundry-rig/docs/`
- Homelab inventory: `infra-lab/HOMELAB-INVENTORY.md`