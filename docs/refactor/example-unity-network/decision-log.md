# Decision Log

## Format

Use one entry per real decision. Keep it short and explicit.

---

## Decision 001

- Date: 2026-07-08
- Status: accepted
- Topic: protocol compatibility
- Decision: preserve the existing wire format exactly during this refactor
- Why: backend and client consumers already depend on current packet encoding
- Supported By Claim IDs: C-001
- Alternatives rejected: protocol cleanup in the same refactor
- Consequence: some awkward encode/decode edges may remain temporarily
- Requires Revalidation If: any touched change alters packet shape, field ordering, or encode/decode ownership

## Decision 002

- Date: 2026-07-08
- Status: accepted
- Topic: responsibility split
- Decision: separate orchestration concerns first, before deeper transport rewrites
- Why: this reduces risk while still improving clarity
- Supported By Claim IDs: C-002, C-004
- Alternatives rejected: full transport redesign in the first slice
- Consequence: initial extraction may still wrap legacy components internally
- Requires Revalidation If: the first slice must move reconnect state or dispatch ordering in the same change

## Decision 003

- Date: 2026-07-08
- Status: accepted
- Topic: thread strategy
- Decision: use one analysis/planning thread and separate short implementation threads per bounded slice
- Why: this keeps token growth bounded while preserving a stable written baseline
- Supported By Claim IDs: C-002, C-003
- Alternatives rejected: one giant thread for the full refactor
- Consequence: handoff summaries become mandatory project artifacts
- Requires Revalidation If: a later slice can no longer be described by the current handoff packet and claim set
