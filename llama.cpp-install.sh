#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status,
# if any variable is used but not set, or if a pipe component fails.
set -euo pipefail

echo "========================================================"
echo " Starting llama.cpp Inference Engine Installation"
echo "========================================================"

# ---------------------------------------------------------------------------
# Target platform
# ---------------------------------------------------------------------------
# pf-host VM: Ubuntu Server 26.04 LTS, NVIDIA Tesla P40 (Pascal, sm_61).
# CUDA toolkit and NVIDIA DKMS driver are ALREADY installed by
# install-cuda.sh in this folder — this script installs the inference
# engine (llama.cpp) itself and does NOT re-touch CUDA or drivers.
#
# HARD CONSTRAINT: FP16 / Tensor-Core (FP16) inference paths — e.g. vLLM
# running unquantized FP16 weights on the P40's Tensor Cores — are NOT
# supported in this lab. The Tesla P40 (Pascal) performs poorly on FP16
# and lacks the compute capacity for unquantized large models. All lab
# models must be served as GGUF quantized weights (q8_0 / q4_k_m).

# Repository root (this script lives in llm-rig/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Function: build the llama.cpp inference engine
# ---------------------------------------------------------------------------
build_llama_cpp() {
  echo "Installing prerequisite build packages..."
  sudo apt-get update
  sudo apt-get install -y build-essential cmake git libssl-dev python3-venv

  # NOTE: libcurl support was REMOVED upstream (llama.cpp commit #18828).
  # TLS for the HF remote fetch now relies on OpenSSL, so we do NOT build
  # with -DLLAMA_CURL. libssl-dev above is the only network dependency.

  echo "Cloning llama.cpp at branch v0.5.0..."
  LLAMA_REPO="${LLAMA_REPO:-https://github.com/ggml-org/llama.cpp}"
  git clone --recurse-submodules --branch v0.5.0 --depth 1 "$LLAMA_REPO" llama.cpp

  echo "Configuring the build (CUDA + native optimizations)..."
  cd llama.cpp
  cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_NATIVE=ON \
    -DCMAKE_CUDA_ARCHITECTURES="70" \
    -Wl,-rpath,/opt/llama.cpp/lib \
    -Wl,-rpath-link,/opt/llama.cpp/lib \
    -DCMAKE_INSTALL_PREFIX=/opt/llama.cpp

  echo "Building llama.cpp (this may take a while)..."
  cmake --build build --config Release -j

  echo "Installing llama.cpp to /opt/llama.cpp..."
  sudo cmake --install build
}

# ---------------------------------------------------------------------------
# Function: install the HF -> GGUF -> quantize conversion pipeline
# ---------------------------------------------------------------------------
setup_quantization() {
  echo "Setting up model conversion / quantization tooling (python)..."

  # Best practice: convert weights to f16 first, then quantize separately.
  if ! python3 -c "import torch, gguf" 2>/dev/null; then
    echo "Creating a virtual environment for torch/gguf..."
    python3 -m venv "$SCRIPT_DIR/.hf-env"
    source "$SCRIPT_DIR/.hf-env/bin/activate"
    pip install --upgrade pip
    pip install torch gguf-py
  else
    echo "torch/gguf already available in $(python3 -c 'import sys; print(sys.prefix)')"
  fi
}

# ---------------------------------------------------------------------------
# Function: convert a HuggingFace model -> GGUF and quantize it
# ---------------------------------------------------------------------------
# Parameters are passed via environment variables (never hardcoded here):
#   HF_MODEL_ID : e.g. TheBloke/Llama-2-7B-Chat-GGUF  (HuggingFace repo id)
#   QUANT_TYPE  : e.g. q4_k_m, q8_0                   (GGUF quantization tag)
#   OUTPUT_DIR   : directory the GGUF files are written to (default: ./models)
# Model names/URLs live in the separate model script, not this engine installer.
convert_and_quantize() {
  HF_MODEL_ID="${HF_MODEL_ID:?HF_MODEL_ID must be set (e.g. TheBloke/Llama-2-7B-Chat-GGUF)}"
  QUANT_TYPE="${QUANT_TYPE:?QUANT_TYPE must be set (e.g. q4_k_m or q8_0)}"
  OUTPUT_DIR="${OUTPUT_DIR:-./models}"
  source "$SCRIPT_DIR/.hf-env/bin/activate"

  echo "Converting ${HF_MODEL_ID} -> ${OUTPUT_DIR}/model-f16.gguf (f16)..."
  python3 convert_hf_to_gguf.py \
    --outfile "${OUTPUT_DIR}/model-f16.gguf" \
    --outtype f16 \
    --remote "${HF_MODEL_ID}"

  echo "Quantizing ${OUTPUT_DIR}/model-f16.gguf -> ${OUTPUT_DIR}/model.${QUANT_TYPE}.gguf..."
  ./build/bin/llama-quantize "${OUTPUT_DIR}/model-f16.gguf" \
    "${OUTPUT_DIR}/model.${QUANT_TYPE}.gguf" "${QUANT_TYPE}"

  echo "Converted + quantized model ready at ${OUTPUT_DIR}/model.${QUANT_TYPE}.gguf"
}

# ---------------------------------------------------------------------------
# Run: build the engine and install the quantize tooling.
# The convert_and_quantize() function is intentionally left for the
# separate model script (which supplies HF_MODEL_ID / QUANT_TYPE).
# ---------------------------------------------------------------------------
build_llama_cpp
setup_quantization

echo "========================================================"
echo " llama.cpp Installation Completed Successfully! "
echo " Inference binaries: build/bin/llama-*"
echo " Quantize tool:      build/bin/llama-quantize"
echo " Convert script:     convert_hf_to_gguf.py"
echo " Run conversion via: HF_MODEL_ID=<id> QUANT_TYPE=<q> ./llama.cpp-install.sh"
echo "========================================================"
