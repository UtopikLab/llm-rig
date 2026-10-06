#!/bin/bash
# Setup script for LiteLLM container

# Generate master key if .env doesn't exist
if [ ! -f /app/.env ]; then
    echo "LITELLM_MASTER_KEY=sk-61316cfcc4baadbcc0303665ee47bb5e97fa1e09759212341ee618e9e8d93765" >> /app/.env
    echo "Master key generated"
fi

# Export the key for the Python process
export LITELLM_MASTER_KEY

# Start LiteLLM
exec /app/.venv/bin/python -m litellm --config /app/config.yaml --port 4000
