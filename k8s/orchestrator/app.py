"""Minimal LangGraph orchestration brain for the llm-rig supervisor/judge.

This module is a *conceptual scaffold* for the LangGraph state machine that
lives in the always-on, CPU-only orchestrator image. It is NOT a full judge
runtime — the real decision-making (the "judge brain") runs on a separate
llama.cpp server on a GPU pod and is reached over the network via the
``judge_url`` tool. This graph models the orchestration loop itself: it owns
the agent state, drives a small planner -> evaluator -> gate cycle, and emits
a final decision.

The scaffold is intentionally runnable without a live judge backend: each
node logs its inputs/outputs and returns the next node. Swap the placeholder
tool calls (``plan``, ``evaluate``, ``judge``) for real LLM-backed tools once
the runtime is wired to the judge server (see supervisor.yaml's JUDGE_URL).

Run locally to explore the graph:

    python3 app.py
"""

from __future__ import annotations

from typing import Annotated, Literal, Sequence, TypedDict

import langgraph  # noqa: F401  (ensures the langgraph runtime is imported)
from langgraph.graph import END, StateGraph


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
class OrchestratorState(TypedDict):
    """The persistent state of a single orchestration task (one issue)."""

    task_id: str
    issue_url: str
    repo: str
    status: Literal["queued", "in_progress", "done"]
    iterations: int
    decision: Literal["accept", "reject", "rerun"]
    notes: str


# ---------------------------------------------------------------------------
# Tools (placeholders — swap for real LLM-backed tools)
# ---------------------------------------------------------------------------
def plan(state: OrchestratorState) -> dict:
    """Node 1: draft a repair plan for the issue.

    In production this calls the judge/LLM tool to produce a concrete plan.
    """
    print(f"[plan] planning {state['task_id']} on {state['repo']}")
    return {"notes": "Draft repair plan for the issue."}


def evaluate(state: OrchestratorState) -> dict:
    """Node 2: evaluate the plan against the issue requirements."""
    print(f"[evaluate] evaluating {state['task_id']}")
    return {"notes": "Plan reviewed against issue requirements."}


def decide(state: OrchestratorState) -> dict:
    """Node 3: gate the evaluated plan and render a final decision."""
    print(f"[decide] final decision for {state['task_id']}: {state['decision']}")
    return {"decision": state["decision"], "notes": "Final gate decision."}


# ---------------------------------------------------------------------------
# Graph
# ---------------------------------------------------------------------------
def build_graph() -> StateGraph[OrchestratorState]:
    """Construct the orchestration state machine."""
    graph = StateGraph(OrchestratorState)

    # Entry point: the supervisor starts the loop here when a task arrives.
    graph.add_node("plan", plan)
    graph.add_node("evaluate", evaluate)
    graph.add_node("decide", decide)

    graph.set_entry_point("plan")
    graph.add_edge("plan", "evaluate")
    graph.add_edge("evaluate", "decide")
    graph.add_edge("decide", END)

    return graph


ORCHESTRATOR_GRAPH = build_graph()

if __name__ == "__main__":
    # Smoke-test the graph so the scaffold is obviously runnable.
    initial: OrchestratorState = {
        "task_id": "<repo>#<issue>",
        "issue_url": "https://github.com/owner/name/issues/1",
        "repo": "owner/name",
        "status": "queued",
        "iterations": 0,
        "decision": "accept",
        "notes": "",
    }
    print("Running orchestration loop for task", initial["task_id"])
    result = ORCHESTRATOR_GRAPH.ainvoke(initial)
    print("Final state:", result)
