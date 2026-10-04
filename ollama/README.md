# Ollama (Node 1 Inference)

- `install-ollama.sh` — installs **Ollama 0.34.0** + a systemd drop-in that binds
  `0.0.0.0:11434`.

Ollama serves a **single model per CUDA context** and does **not** split a model
across both P40s. Use it only for 7B-class GGUFs; large models should be served
with `llama.cpp` tensor-split across both GPUs (see
[`../llama-cpp/README.md`](../llama-cpp/README.md)).

See [`../README.md`](../README.md) for the full run order.
