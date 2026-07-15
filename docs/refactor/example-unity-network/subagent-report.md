# Subagent Report

## Mission

- Requested investigation: Identify the narrowest safe extraction seam between orchestration and reconnect/liveness handling.

## Boundaries

- In scope: Current manager lifecycle, reconnect state, heartbeat path.
- Out of scope: Protocol redesign, gameplay consumer changes, backend contract changes.

## Findings

1. Reconnect and heartbeat share lifecycle state, so extraction must move both or neither.
2. Public caller-visible lifecycle callbacks appear to depend on the current state transition order.
3. Dispatch ordering risk is orthogonal and should be validated separately from lifecycle extraction.

## Evidence Claim Seeds

- Proposed Claim ID: C-004
- Conclusion: Reconnect and heartbeat logic are coupled to shared lifecycle state.
- Source Type: code-read
- Source Location: lifecycle and reconnect branches in the current manager
- Confidence: medium

## Unknowns

- Unknown: Whether all reconnect state writes can move together in the first slice.
- Why still unresolved: Needs a bounded implementation pass plus regression checks.

## Conflicts With Existing Claims

- None. This report sharpens C-004 rather than contradicting it.

## Recommended Next Check

- Next verification step: Compare lifecycle state mutations before and after the extraction candidate.
