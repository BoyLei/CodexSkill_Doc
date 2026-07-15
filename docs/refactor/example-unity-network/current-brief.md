# Current Brief

## Objective

- Split network orchestration from transport / protocol / dispatch concerns without changing the existing protocol shape or externally visible behavior.

## Non-Goals

- No backend API changes
- No protocol schema redesign
- No gameplay message handler rewrite
- No speculative abstraction for future transports unless immediately needed by the refactor

## Exact Scope

- Files:
  - current network entrypoint and adjacent network-layer files only
- Symbols:
  - orchestration entrypoints
  - transport-facing send/receive hooks
  - decode / dispatch glue
- Tests:
  - focused network-layer behavior checks
  - smoke validation for connection lifecycle and message dispatch
- Evidence Claim IDs:
  - C-001
  - C-002
  - C-003
  - C-005

## Constraints

- Behavior that must stay identical:
  - packet format
  - message ordering semantics
  - connection lifecycle semantics visible to callers
- Interface / protocol constraints:
  - existing public entrypoints should remain stable unless explicitly logged
- Performance / reliability constraints:
  - do not add extra copies, blocking hops, or main-thread unsafe work
- Evidence Claim IDs:
  - C-001
  - C-003
  - C-005

## Planned Changes

1. Extract explicit orchestration responsibilities from the current monolithic manager
2. Introduce clear internal boundaries between transport, protocol, and dispatch concerns
3. Add focused validation around reconnection, encoding/decoding, and dispatch handoff

## Known Unknowns

- Unknown: Exact extraction seam for reconnect state ownership.
- Why it is still open: C-004 shows coupling, but the smallest safe slice still needs proof.
- Required follow-up: Validate lifecycle state writes before and after the chosen extraction.

## Success Criteria

- [ ] Code compiles or equivalent static validation passes
- [ ] Existing behavior is preserved
- [ ] Required tests pass
- [ ] No new cross-layer dependency is introduced
- Evidence Claim IDs:
  - C-001
  - C-003
  - C-005

## Handoff Summary

Use this block when opening a new implementation thread:

```text
Context:
- Refactor target: Unity network layer
- Current scope: split orchestration from transport/protocol/dispatch glue
- Non-goals: no protocol or backend changes
- Constraints: preserve packet format, ordering, lifecycle semantics
- Evidence Claim IDs: C-001, C-002, C-003, C-005
- Known unknowns: reconnect state ownership extraction seam
- Next step: implement one bounded extraction and verify no new cross-layer dependency appears
```
