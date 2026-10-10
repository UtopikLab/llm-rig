# Next chat session — paste this verbatim

---

## Project: k8s-node01 — LangGraph orchestrator (two-brain K3s, single node)

You are continuing a deployment-unblock effort. Here is everything needed to
resume without re-reading prior context.

### Architecture
- Bare-metal **K3s single-node cluster** `k8s-node01`: Intel Xeon Gold 6148
  (80 cores, 91 GiB RAM), 2× NVIDIA Tesla P40 (23 GiB VRAM, **no tensor
  cores**). containerd backend; on this box only `ctr` + `crictl` (no docker/
  nerdctl).
- **Judge brain** (llama.cpp Qwen2.5-Coder, `inference/`): GPU pod in namespace
  `llm`, served at `https://llm.local/v1` (host `llm-server-gpu1`). Prereq
  runtime service — must be running before a task can complete.
- **Orchestrator brain** (LangGraph, `orchestrator/`): always-on CPU-only
  supervisor Deployment in namespace `orchestrator`, port `:8000`, running the
  state machine (`OrchestratorState` TypedDict: `task_id, issue_url, repo,
  status, iterations, decision, notes`). The resident loop calls the judge
  brain over the network.

### What is done
- Code lives in **`UtopikLab/code-factory`** (extracted from parent
  `UtopikLab/llm-rig` via `git subtree split`, the former `k8s/` at repo root).
  Code currently in `/home/user/llm-rig/k8s` is a local clone before the fresh
  clone.
- `main` pushed to remote (`429c90c`). Repo is **private**.
- Build & run plan: `THINKTANK-BUILD-PLAN.md` (Phases A–F, dependency order).
  Design doc: `thinktank-plan.md`. Hardware node doc: `k8s-node01.md`.
- Secrets policy: **real secrets handled in-cluster only** — never echo/persist
  them. OpenAI key + GitHub PAT are stored in secret `orchestrator-secrets`.

### Approval / constraints (re-state before acting)
- Approved: kubectl/git (§3), NVIDIA device-plugin + Traefik Ingress (§4),
  llama.cpp/Graphene/Prometheus/iDRAC/node-exporter from official sources (§5).
- **NOT approved:** buildah/docker/nerdctl — image build must run on a **separate
  build host**, never on k8s-node01.
- Image: `ghcr.io/UtopikLab/langgraph-orchestrator:latest`, base `python:3.11`.
- Does **not** build wide `requirements.txt` ranges.

### Pending work (priority order)
1. **Rotate the expired PAT** (the one baked into `orchestrator-secrets`
   `github-token` is expired ~2026-08-08). Recreate the secret **in-cluster only**
   from the rotated PAT — do not echo it. Verify with
   `kubectl get secret orchestrator-secrets -n orchestrator -o yaml`.
2. **Cluster connectivity:** `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml`
   (per `k8s-node01.md` §3); `kubectl version --client && kubectl cluster-info`
   and `kubectl get nodes -o wide` (confirm Ready). Last `kubectl` returned
   Exit 1 — diagnose.
3. **ConfigMap `orchestrator-config`** (policy knobs from `orchestrator/workers.yaml`
   data): `max-iterations, task-wait-seconds, loop-state-dir, judge-url,
   judge-model`.
4. **iDRAC secret:** `monitoring/secrets.yaml` →
   `kubectl create secret generic idrac-credentials --namespace monitoring
   --from-literal=password=<pw>`.
5. **Judge brain check:** `kubectl wait --for=condition=ready pod --all -n llm
   --timeout=180s` then a curl to `https://llm.local/v1/chat/completions`.
6. **Build & push image** (on a **separate build host**, decision pending:
   buildah vs docker/nerdctl). From `code-factory/k8s/orchestrator`:
   `buildah login -u <gh-user> -p <gh-pat> ghcr.io && buildah bud -f
   Dockerfile -t ghcr.io/UtopikLab/langgraph-orchestrator:latest . && buildah
   push ...`.
7. **Deploy stack:** `namespace.yaml`, `supervisor.yaml` (Deployment+Service:8000),
   `workers.yaml` (Job template + ConfigMap), Traefik Ingress →
   `orchestrator.orchestrator.svc:8000`.
8. **Validate (Phase D):** `kubectl -n orchestrator wait --for=condition=ready
   pod -l app=orchestrator --timeout=180s`, check Service, `curl
   http://localhost:8000/healthz` via exec.
9. **Monitoring (Phase E):** apply `monitoring/node-exporter.yaml` +
   `monitoring/idrac.yaml`; wire central Prometheus on TrueNAS
   (`http://truenas.utopiklab.lan:30104/`).
10. **Trigger first task (Phase F):** push a branch that opens an issue (via
    `.github/workflows/drain.yaml`, uses `$GITHUB_TOKEN`) **or** manual curl to
    `POST /api/v1/tasks/spawn` with the PAT.

### Key files
- `orchestrator/app.py` (LangGraph state machine), `supervisor-task-acceptor.py`
  (acceptor renders `agent-job-template.yaml` with `${TASK_ID}`, `${ISSUE_URL}`,
  `${REPO}`, `${GITHUB_TOKEN}`; `kubectl apply` + `kubectl wait --for=jobcomplete`).
- `orchestrator/supervisor.yaml`, `orchestrator/workers.yaml`,
  `orchestrator/agent-job-template.yaml`, `orchestrator/Dockerfile`,
  `orchestrator/requirements.txt`, `orchestrator/secrets.yaml` (template).
- `inference/{common.sh,deploy.sh,deployment.yaml,models-pvc.yaml,
  nvidia-device-plugin.yaml}`.
- `.github/workflows/{build-push.yaml (triggers on push→main, targets ghcr.io),
  drain.yaml}`.
