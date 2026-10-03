# llm-rig

Homelab **LLM & image-tool POC repository** for the `192.168.1.0/24` subnet.
This repo holds proof-of-concept setups for local LLM tooling — grouped by POC,
with all documentation centralized under [`docs/`](docs/).

It focuses on the **local inference/image stack only**. It does **not** document
the other three homelab nodes (Development Command Center, Data Backbone,
Orchestration/Promptflow) — those live in `foundry-rig/` and `infra-lab/`.

## POC Inventory

| POC | What it is | Stack | Docs |
|-----|-----------|-------|------|
| **Node 1 — Inference Rig** | 2× Tesla P40 (R740xd) local LLM inference | llama.cpp (`GGML_CUDA`) + Ollama, GGUF `q8_0`/`q4_k_m` | [`docs/node1-inference.md`](docs/node1-inference.md) · scripts [`driver/`](driver), [`llama-cpp/`](llama-cpp), [`ollama/`](ollama), [`models/`](models) |
| **ComfyUI** | Node-based Stable Diffusion / image generation | ComfyUI (Docker or pip), PyTorch | [`docs/comfyui.md`](docs/comfyui.md) · scripts [`comfyui/`](comfyui) |

> **P40 note.** The Tesla P40 is Pascal (compute 6.1) — CUDA-capable but poor on
> FP16. All lab LLM models are served as GGUF INT8/Q4_K_M; image generation runs
> best on the RTX 3080 (Node 2, Ampere) or CPU. See [`docs/comfyui.md`](docs/comfyui.md).

## Repo layout

```
llm-rig/
├── README.md                       # this file — root overview + POC inventory
├── docs/                           # ALL documentation (except this README)
│   ├── README.md                   # docs navigation index
│   ├── node1-inference.md          # Node 1 inference blueprint
│   ├── comfyui.md                  # ComfyUI POC doc
│   └── adr/
│       └── 0001-repo-layout.md     # repo layout decision (ADRs)
├── driver/                         # install-cuda.sh (NVIDIA driver + CUDA 13)
├── llama-cpp/                      # llama.cpp-install.sh (CUDA build)
├── ollama/                         # install-ollama.sh
├── models/                         # downloaded GGUF weights (model-weights.sh)
├── comfyui/                        # ComfyUI POC (image generation)
│   ├── scripts/                    # ComfyUI install/deploy scripts
│   └── models/                     # downloaded checkpoints / pipelines
└── .gitignore
```

**Layout rules** (see [`docs/adr/0001-repo-layout.md`](docs/adr/0001-repo-layout.md)):

- **All documentation lives in `docs/`** — never scatter markdown into ad-hoc or
  top-level locations (the only exception is this root `README.md`).
- **Scripts grouped by component** at the repo root — `driver/`, `llama-cpp/`,
  `ollama/`, and `models/` for the Node 1 rig; `comfyui/` for image-gen scripts.
- **Adding a new POC** is a one-page pattern: create a folder at the repo root
  for its scripts (grouped by component) and a `models/` folder for downloads,
  plus `docs/<name>.md` for its documentation, then list it in the POC inventory
  above.

## Documentation

See [`docs/`](docs/) for the full documentation set:

- [`docs/node1-inference.md`](docs/node1-inference.md) — architecture + 8-phase
  deployment plan for the Node 1 inference rig.
- [`docs/comfyui.md`](docs/comfyui.md) — ComfyUI POC (hardware fit, install, wiring).
- [`docs/adr/0001-repo-layout.md`](docs/adr/0001-repo-layout.md) — repo layout decision.

## Contributing
Each POC lives at the repo root as its own folder.

Keep scripts grouped by component and all docs under `docs/`.
New POCs follow the pattern above and are added to the POC inventory.

## Related

- Full 4-node blueprint: `foundry-rig/docs/`
- Homelab inventory: `infra-lab/HOMELAB-INVENTORY.md`