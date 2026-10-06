#!/bin/bash
# Generate LiteLLM master key if not exists
if [ ! -f /app/.env ]; then
    echo "LITELLM_MASTER_KEY=sk-$(openssl rand -hex 32)" >> /app/.env
    echo "Master key generated"
fi

# Export the key
export LITELLM_MASTER_KEY

echo "Starting LiteLLM..."
exec /app/.venv/bin/python -m litellm --config /app/config.yaml --port 4000
