# Open Risks

## Active Risks

| ID | Risk | Impact | Mitigation | Owner | Status | Triggered By Claim IDs | What would falsify this risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-001 | Hidden ordering dependency in current dispatch path | gameplay regressions that are hard to spot quickly | keep dispatch semantics stable, add focused ordering checks before changing internals | Codex | open | C-003 | Before/after ordering checks show no behavior-sensitive ordering difference |
| R-002 | Reconnect logic may rely on shared mutable state spread across the manager | silent reconnect failures after extraction | isolate lifecycle state changes and validate reconnect flow separately | Codex | open | C-004 | Lifecycle state ownership is made explicit and reconnect smoke checks pass |
| R-003 | Unity-thread handoff assumptions may be implicit rather than documented | race or threading regressions | treat main-thread boundary as an invariant and record any touched callsites | Codex | open | C-005 | All touched dispatch callsites remain on the Unity-safe side and smoke checks pass |

## Deferred Risks

| ID | Deferred Because | Revisit When |
| --- | --- | --- |
| D-001 | Transport abstraction cleanup is useful but not required for the first safe slice | after orchestration split is stable |
| D-002 | Protocol dictionary ergonomics are messy but compatibility pressure is higher | after behavior-preserving extraction is complete |

## Notes

- Keep only unresolved risks here
- Remove risks that are fully closed
- If a risk changes architecture, update `decision-log.md`
