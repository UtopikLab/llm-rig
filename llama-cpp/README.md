# llama.cpp (Node 1 Inference)

- `llama.cpp-install.sh` — build llama.cpp with **`GGML_CUDA=ON`**, CUDA arch
  **`61`** (Pascal P40), OpenSSL-based (`LLAMA_OPENSSL`), rpath flags.

This builds the inference engine (`llama-server`) and quantization tooling. It
expects the driver + CUDA to already be installed by `driver/install-cuda.sh`.

> Do **not** build with `-DLLAMA_CURL=ON` — libcurl support was removed
> (commit #18828); use OpenSSL instead.

See [`../README.md`](../README.md) for the full run order.
