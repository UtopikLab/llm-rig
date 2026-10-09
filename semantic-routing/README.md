# Semantic Routing LLM Rig

A Docker Compose setup that runs two Ollama instances — one bound to each NVIDIA GPU — behind a LiteLLM gateway router. This rig is intended for a homelab operator who wants to route LLM inference across two discrete GPUs through a single entry point.

## Services

| Service        | External Port | GPU  | Purpose                        |
| -------------- | ------------- | ---- | ------------------------------ |
| `ollama-gpu0`  | `11434`       | 0    | Ollama server (max 2 loaded)   |
| `ollama-gpu1`  | `11435`       | 1    | Ollama server (max 1 loaded)   |
| `litellm`      | `4000`        | —    | LiteLLM gateway router         |
| `db`           | —             | —    | PostgreSQL data store          |

Both Ollama containers mount `./models` to `/root/.ollama`, so models live in the `./models` folder and persist across restarts.

## Overview

The rig is split into two parts:

- **Ollama servers** (`ollama-gpu0`, `ollama-gpu1`) — the actual inference workers, each pinned to a specific GPU.
- **LiteLLM gateway** (`litellm`) — the public-facing router on port `4000` that forwards requests to the Ollama servers and can also be used to pull models.

To bring the services up, use the Ollama compose file:

```bash
docker compose --file '/home/user/llm-rig/semantic-routing/docker-compose.ollama.yaml' --project-name 'semantic-routing' up -d
```

## Pull a model

Ollama needs GPU access to load models, so pull them **inside** the container:

```bash
# Pull onto GPU 0 (port 11434)
docker exec -it ollama-gpu0 ollama pull <model>

# Pull onto GPU 1 (port 11435)
docker exec -it ollama-gpu1 ollama pull <model>
```

Example:

```bash
docker exec -it ollama-gpu0 ollama pull qwen2.5:7b
```

List installed models:

```bash
docker exec -it ollama-gpu0 ollama list
```

> Pulling to the host and relying on auto-mount does **not** work here, because the `./models` volume overrides `/root/.ollama` inside the container.

## Pull via the LiteLLM gateway

The gateway proxies to Ollama, so you can pull through it as well:

```bash
ollama --base-url http://localhost:4000/v1 pull <model>
```

## NVIDIA Container Toolkit Required

The Ollama containers bind to NVIDIA GPUs (0 and 1), so the host must have the `nvidia-container-toolkit` installed, otherwise containers fail with:

`could not select device driver "nvidia" with capabilities: [[gpu]]`

Install the toolkit with the following commands:

```bash
# Add NVIDIA repository key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Add repository
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update and install
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use the nvidia runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker service
sudo systemctl restart docker
```

After installation, restart the containers so they pick up the new runtime:

```bash
docker compose --file '/home/user/llm-rig/semantic-routing/docker-compose.ollama.yaml' --project-name 'semantic-routing' up -d
```

Verify that GPU access works:

```bash
docker exec -it ollama-gpu0 nvidia-smi
```
