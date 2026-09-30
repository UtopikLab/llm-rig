#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status,
# if any variable is used but not set, or if a pipe component fails.
set -euo pipefail

echo "========================================================"
echo " Starting Model Weights Deployment (GGUF, P40-optimized)"
echo "========================================================"

# ---------------------------------------------------------------------------
# Target platform
# ---------------------------------------------------------------------------
# pf-host VM: Ubuntu Server 26.04 LTS, NVIDIA Tesla P40 (Pascal, sm_70).
# The Tesla P40 performs extremely poorly on FP16. All lab models MUST be
# served as GGUF quantized weights. Only Q8_0 / Q4_K_M (INT8 / DP4A) are
# acceptable on the P40 — Q5_K_M / FP16 are acceptable only on Ampere-class
# GPUs (e.g. RTX 3080, Node 2).

# Base directory for model artifacts.
MODELS_DIR="${MODELS_DIR:-$SCRIPT_DIR/../models}"

# ---------------------------------------------------------------------------
# Function: install download prerequisites
# ---------------------------------------------------------------------------
install_prereqs() {
  echo "Installing download prerequisites..."
  sudo apt-get update
  sudo apt-get install -y wget ca-certificates
}

# ---------------------------------------------------------------------------
# Function: download a GGUF model (assumes GGUF weights are already
# available on HuggingFace, e.g. TheBloke/*-GGUF repos)
# ---------------------------------------------------------------------------
download_model() {
  local HF_MODEL_ID="${1:?HF_MODEL_ID required (e.g. TheBloke/Llama-2-7B-Chat-GGUF)}"
  local QUANT_TYPE="${2:?QUANT_TYPE required (e.g. q4_k_m or q8_0)}"
  local TARGET_NAME="model.${QUANT_TYPE}.gguf"

  echo "Downloading ${HF_MODEL_ID} @ ${QUANT_TYPE}..."
  wget -O "${MODELS_DIR}/${TARGET_NAME}" \
    "https://huggingface.co/${HF_MODEL_ID}/resolve/main/${TARGET_NAME}"

  echo "Saved ${MODELS_DIR}/${TARGET_NAME}"
}

# ---------------------------------------------------------------------------
# Function: print the P40 deployment checklist
# ---------------------------------------------------------------------------
print_checklist() {
  echo ""
  echo "--------------------------------------------------------"
  echo " P40 GGUF Deployment Checklist"
  echo "--------------------------------------------------------"
  echo " [ ] Run 'nvidia-smi' — confirm both P40s (24GB x2) visible, ECC ON"
  echo " [ ] For each model, GGUF variants to deploy:"
  echo "      - q8_0  GGUF  (highest fidelity, ~8.5GB/7B)  [recommended]"
  echo "      - q4_k_m GGUF (size/quality tradeoff, ~4.5GB/7B)"
  echo " [ ] Verify GPU offload: LLAMA_CUDA=1 ./build/bin/llama-cli ..."
  echo " [ ] Verify tensor-split 0.5,0.5 across the two PCIe buses (175/216)"
  echo " [ ] Confirm model loaded from GGUF (NOT unquantized FP16)"
  echo "--------------------------------------------------------"
}

main() {
  install_prereqs

  # Example model deployments (override with your own HF_MODEL_ID / QUANT_TYPE).
  # Each entry downloads a single quantized GGUF variant.
  #
  #   TheBloke/Llama-2-7B-Chat-GGUF        -> q4_k_m, q8_0
  #   NousResearch/Nous-Hermes-3-70B       -> q4_k_m, q8_0  (70B is large on P40)
  #   Qwen/Qwen2.5-Coder-32B-Instruct      -> q8_0          (matches arch doc example)

  # 1. q8_0 GGUF (recommended — INT8 / DP4A)
  download_model "TheBloke/Llama-2-7B-Chat-GGUF" "q8_0"

  # 2. q4_k_m GGUF (size/quality tradeoff — INT8 / DP4A)
  download_model "TheBloke/Llama-2-7B-Chat-GGUF" "q4_k_m"

  print_checklist
}

main
