# Handoff Checklist

## Decision Packet

- Current objective: Extract one orchestration slice from `NetworkManager` without changing packet format, dispatch ordering, or externally visible lifecycle behavior.
- Non-goals: No backend changes, no wire-format change, no gameplay handler rewrite, no speculative transport redesign.
- Exact scope: Network entrypoint plus adjacent transport/protocol/dispatch glue only.
- Architecture boundaries: Preserve protocol shape, keep gameplay semantics out of transport, keep Unity-thread-affine work on the Unity-safe side.
- Accepted decisions: Decision 001, Decision 002, Decision 003.
- Open risks: R-001, R-002, R-003.
- Known unknowns: Exact extraction seam for reconnect state ownership.
- Done condition: One bounded extraction lands, behavior is preserved, and no new cross-layer dependency appears.

## Required References

- `architecture-baseline.md` updated: yes
- `current-brief.md` updated: yes
- `decision-log.md` updated: yes
- `open-risks.md` updated: yes
- `evidence-ledger.md` claim IDs included in handoff: yes

## Handoff Prompt Stub

```text
Context:
- Objective: extract one orchestration slice from the Unity network layer
- Scope: network entrypoint plus adjacent transport/protocol/dispatch glue
- Non-goals: no protocol or backend changes
- Constraints: preserve packet format, dispatch ordering, lifecycle semantics
- Claim IDs: C-001, C-002, C-003, C-005
- Risks: R-001, R-002, R-003
- Unknowns: reconnect state ownership extraction seam
- Done condition: one bounded extraction with no new cross-layer dependency
```
