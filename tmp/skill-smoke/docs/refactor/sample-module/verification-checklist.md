# Verification Checklist

## Behavior

- [ ] Main behavior is unchanged
- [ ] Edge cases still behave correctly
- [ ] Error paths still behave correctly

Evidence:

- Claim IDs:
- Tests:
- Runtime / manual evidence:

## Interfaces

- [ ] Public API / protocol shape is unchanged, or approved changes are documented
- [ ] Callers still compile or equivalent checks pass

Evidence:

- Claim IDs:
- Static or caller checks:

## Tests

- [ ] Existing relevant tests pass
- [ ] New tests added where the refactor introduced risk
- [ ] Manual validation completed if automated coverage is insufficient

Evidence:

- Claim IDs:
- Test runs:
- Manual validation:

## Architecture

- [ ] No accidental cross-layer dependency was introduced
- [ ] Final code still matches `architecture-baseline.md`
- [ ] Final code still matches `current-brief.md`

Evidence:

- Claim IDs:
- Diff or dependency review:

## Risks

- [ ] `open-risks.md` is updated
- [ ] Remaining risks are explicitly accepted or scheduled

Evidence:

- Claim IDs:
- Final acceptance record:
