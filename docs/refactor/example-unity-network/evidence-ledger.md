# Evidence Ledger

## Claim 001

- Claim ID: C-001
- Conclusion: The existing packet wire format must remain unchanged during the refactor.
- Source Type: architecture constraint
- Source Location: protocol encode/decode path and existing consumer contract review
- Reasoning: Backend compatibility is a hard boundary, so a behavior-preserving refactor cannot alter packet shape.
- Confidence: high
- Unknowns: None for the first slice.
- Last Verified At: 2026-07-08

## Claim 002

- Claim ID: C-002
- Conclusion: `NetworkManager` currently mixes orchestration, transport decisions, and dispatch concerns.
- Source Type: code-read
- Source Location: current manager entrypoints and adjacent network-layer files
- Reasoning: One class owns lifecycle, socket coordination, decode/dispatch glue, and retry behavior.
- Confidence: high
- Unknowns: Exact extraction seams still need to be proven with a concrete slice.
- Last Verified At: 2026-07-08

## Claim 003

- Claim ID: C-003
- Conclusion: Dispatch ordering semantics are a high-risk invariant and must be preserved.
- Source Type: behavior analysis
- Source Location: dispatch path and consumer assumptions
- Reasoning: Reordering callbacks would create subtle gameplay regressions even if the transport still works.
- Confidence: medium
- Unknowns: Need focused ordering checks during implementation.
- Last Verified At: 2026-07-08

## Claim 004

- Claim ID: C-004
- Conclusion: Reconnect and heartbeat logic are coupled to shared lifecycle state.
- Source Type: code-read
- Source Location: reconnect and liveness branches in the current network manager
- Reasoning: Extraction can break recovery behavior unless state ownership is made explicit.
- Confidence: medium
- Unknowns: Which state fields must move together in the first safe slice.
- Last Verified At: 2026-07-08

## Claim 005

- Claim ID: C-005
- Conclusion: Unity-thread-affine dispatch must stay on the Unity-safe side of the boundary.
- Source Type: architecture invariant
- Source Location: dispatch handoff path and caller expectations
- Reasoning: Main-thread violations would create race or runtime issues even if API signatures stayed stable.
- Confidence: high
- Unknowns: Confirm exact touched callsites during implementation.
- Last Verified At: 2026-07-08
