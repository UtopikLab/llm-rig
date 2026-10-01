# llm-rig

Dedicated repository for the **local LLM inference stack** (Node 1) of this homelab — the 2× Tesla P40 GPU rig. This repo covers **only** the inference-rig software (llama.cpp + Ollama). It does **not** document the other three nodes (Development Command Center, Data Backbone, Orchestration/Promptflow) defined in `foundry-rig/` and `infra-lab/`.

## Scope

- **Node 1 (pf-host / R740xd)** — dedicated inference rig running CUDA-accelerated local LLM inference.
- Does **not** cover: Node 2 (DESKTOP-STEEVE), Node 3 (TS430 storage/NFS/Qdrant), Node 4 (M70q orchestration). See `foundry-rig/docs/` for the full 4-node blueprint.

### FP16 constraint

P40 performs poorly on FP16 and lacks compute for unquantized large models. **All lab models must be served as GGUF quantized** (`q8_0`, `q4_k_m`).

## Stack

- **llama.cpp** `v0.25.1`, built with `GGML_CUDA=ON` + `GGML_NATIVE=ON`, CUDA arch `61`, OpenSSL-based (`LLAMA_OPENSSL`).
- **Ollama** `0.34.0`.
- **Inference** served via `llama-server --tensor-split 0.5,0.5` (one GPU per P40).
- Build output: `/opt/llama.cpp/` (bin/ + lib/, root-owned).

## Scripts

| Script | Purpose |
|---|---|
| `install-cuda.sh` | NVIDIA 620.32.03 driver + CUDA 13.0.2 |
| `install-ollama.sh` | Ollama 0.34.0 + systemd drop-in |
| `llama.cpp-install.sh` | Build llama.cpp (CUDA arch `61`, rpath flags) |
| `model-weights.sh` | Download + quantize models (GGUF, P40-optimized) |

## Docs

- `docs/node1-inference.md` — full architecture + 8-phase deployment plan for Node 1.

## Build output

`/opt/llama.cpp/` — llama.cpp build artifacts (bin/ + lib/). Executables are root-owned.

## Known issue: `llama-server` won't start (exit 127)

`llama-server` fails with exit 127 because its nested shared libraries (`libllama-server-impl.so`, etc.) are **not found** — the runtime linker can't resolve them. Root cause: the systemd unit's `Environment=` line is empty, so `LD_LIBRARY_PATH=/opt/llama.cpp/lib` is never set.

**Immediate workaround** (without rebuilding):

```bash
systemctl edit llama-server.service
# add: Environment="LD_LIBRARY_PATH=/opt/llama.cpp/lib"
systemctl daemon-reload && systemctl restart llama-server
```

**Permanent fix:** rebuild llama.cpp with `RPATH` flags (see `llama.cpp-install.sh`).

## Related

- Full 4-node blueprint: `foundry-rig/docs/`
- Homelab inventory: `infra-lab/HOMELAB-INVENTORY.md`