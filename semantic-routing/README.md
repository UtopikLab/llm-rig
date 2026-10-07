# Semantic Routing LLM Rig

A Docker Compose setup running two Ollama instances (one per GPU) behind a LiteLLM gateway router.

## Services

| Service        | External Port | GPU  | Purpose                        |
| -------------- | ------------- | ---- | ------------------------------ |
| `ollama-gpu0`  | `11434`       | 0    | Ollama server (max 2 loaded)   |
| `ollama-gpu1`  | `11435`       | 1    | Ollama server (max 1 loaded)   |
| `litellm`      | `4000`        | —    | LiteLLM gateway router         |
| `db`           | —             | —    | PostgreSQL data store          |

Both Ollama containers mount `./models` to `/root/.ollama`, so models live in the `./models` folder and persist across restarts.

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
