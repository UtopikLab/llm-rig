# ---------------------------------------------------------------------------
# LangGraph orchestrator runtime image.
#
# This image is the value substituted for the ${IMAGE} placeholder in
#   orchestrator/supervisor.yaml        (the supervisor Deployment's image)
#   orchestrator/agent-job-template.yaml (the agent Job's container image)
#
# It is a CPU-only, always-on runtime: the supervisor/judge holds a resident
# LangGraph state machine and hosts a token-authed task-acceptor HTTP sidecar
# on port 8000. It intentionally does NOT include torch / transformers /
# langchain-openai — the judge model backend runs on a separate llama.cpp
# server on a GPU pod, reachable over the network.
# ---------------------------------------------------------------------------
FROM python:3.11-slim

# Python 3.11 is chosen because LangGraph requires 3.11+ (3.10+ is the floor
# for langgraph itself; 3.11 gives headroom for langgraph-sdk / langchain-core).
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install CPU-only runtime dependencies.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

# Workspace: the supervisor ships the rendered agent Job template alongside
# the runtime so the pod has a single source of truth for the Job it renders
# at spawn time (see supervisor.yaml: AGENT_JOB_TEMPLATE -> /opt/orchestrator).
WORKDIR /opt/orchestrator
COPY agent-job-template.yaml /opt/orchestrator/agent-job-template.yaml
COPY supervisor-task-acceptor.py /opt/orchestrator/supervisor-task-acceptor.py

# LangGraph CLI entrypoint lives under the runtime package; `python3 -m
# langgraph.cli serve` boots the state-machine runtime. The supervisor also
# hosts the :8000 task-acceptor sidecar (supervisor-task-acceptor.py) in the
# same process.
EXPOSE 8000

# Minimal, documented entrypoint. The supervisor's long-running loop is
# launched via `python3 -m langgraph.cli serve`; the :8000 sidecar is started
# by the same command (see supervisor.yaml). Keep this minimal: do not add
# extra orchestration here — the manifest (supervisor.yaml) already wires up
# the loop state-dir, probes, and env.
ENTRYPOINT ["python3", "-m", "langgraph.cli", "serve"]
