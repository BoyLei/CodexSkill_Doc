# Verification Checklist

## Behavior

- [ ] Main behavior is unchanged
- [ ] Edge cases still behave correctly
- [ ] Error paths still behave correctly

Evidence:

- Claim IDs: C-003, C-004, C-005
- Tests: Connection lifecycle before/after comparison
- Runtime / manual evidence: Representative message dispatch path and reconnect recovery check

## Interfaces

- [ ] Public API / protocol shape is unchanged, or approved changes are documented
- [ ] Callers still compile or equivalent checks pass

Evidence:

- Claim IDs: C-001, C-005
- Static or caller checks: Public entrypoint diff review and protocol encode/decode compatibility confirmation

## Tests

- [ ] Existing relevant tests pass
- [ ] New tests added where the refactor introduced risk
- [ ] Manual validation completed if automated coverage is insufficient

Evidence:

- Claim IDs: C-003, C-004
- Test runs: Network-layer tests
- Manual validation: Smoke validation for connect / send / receive / reconnect

## Architecture

- [ ] No accidental cross-layer dependency was introduced
- [ ] Final code still matches `architecture-baseline.md`
- [ ] Final code still matches `current-brief.md`

Evidence:

- Claim IDs: C-002, C-005
- Diff or dependency review: Touched-module dependency review and brief-to-diff cross-check

## Risks

- [ ] `open-risks.md` is updated
- [ ] Remaining risks are explicitly accepted or scheduled

Evidence:

- Claim IDs: C-003, C-004, C-005
- Final acceptance record: Final risk review before merge
