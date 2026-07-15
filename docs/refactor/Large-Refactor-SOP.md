# Large Refactor SOP

## Goal

Use this workflow for large project refactors that require many rounds of analysis, confirmation, implementation, and review while keeping:

1. Critical information intact
2. Architecture decisions coherent
3. Token usage bounded

## Core Rule

Do not let the chat thread become the long-term memory for the refactor.

Long-term memory must live in files under `docs/refactor/`. Threads should carry only the current step, current diff, and current blocker.

Summaries are navigation aids only. They do not replace code, trace, test, or runtime evidence.

## Required Artifacts

Maintain these files for every substantial refactor:

1. `templates/architecture-baseline.md`
2. `templates/current-brief.md`
3. `templates/decision-log.md`
4. `templates/open-risks.md`
5. `templates/verification-checklist.md`
6. `templates/evidence-ledger.md`
7. `templates/handoff-checklist.md`
8. `templates/subagent-report.md`

Copy the templates into a task-specific folder before starting, for example:

```text
docs/refactor/payment-service/
docs/refactor/network-layer/
docs/refactor/unity-network-redesign/
```

## Workflow

### Stage A: Scout

Objective: build architecture understanding without implementing.

Outputs:

- `architecture-baseline.md`
- first draft of `open-risks.md`

Rules:

- Read code broadly, write only summaries
- Prefer graph/index tools over broad file dumps
- Do not carry raw tool output forward; summarize it
- Every architecture-affecting summary must point to a `Claim ID`

### Stage B: Plan

Objective: define the exact refactor boundary.

Outputs:

- `current-brief.md`
- `decision-log.md`

Rules:

- Lock the target modules and non-goals
- Record every architecture-level decision explicitly
- If the design changes, update the files before continuing
- High-risk conclusions must exist in `evidence-ledger.md` before they enter the plan

### Stage C: Implement

Objective: execute one bounded slice at a time.

Inputs:

- `architecture-baseline.md`
- `current-brief.md`
- relevant code files only

Rules:

- Use a short-lived implementation thread
- Do not re-explore the whole project in the implementation thread
- If new architectural uncertainty appears, stop and return to Stage B
- Do not start the implementation thread until `handoff-checklist.md` is complete

### Stage D: Revise

Objective: improve structure and readability after behavior is correct.

Outputs:

- updates to `decision-log.md` if code shape changes materially

Rules:

- Review names, file boundaries, duplication, and function size
- Keep this separate from architectural redesign
- If the cleanup changes architecture assumptions, create or update the supporting claims first

### Stage E: Verify

Objective: prove the refactor is correct.

Outputs:

- completed `verification-checklist.md`

Rules:

- Verify behavior, interfaces, tests, and risks
- Do not mark done from intuition
- Verification evidence must cite claim IDs, test results, or runtime evidence directly

## Threading Strategy

Use different threads for different stages.

- Analysis thread: Scout + early Plan
- Implementation thread: one bounded implementation slice
- Review thread: revise or verify only

Never keep the full history of every stage in one thread when the project is large.

Subagents are allowed only as bounded investigators. Their output must be compressed into `subagent-report.md` before the main thread relies on it.

## Token Control Rules

### Always do

- Carry forward summaries, not raw logs
- Carry forward claim IDs, not just prose conclusions
- Reopen a fresh thread after the brief is stable
- Limit command output to the minimum lines needed
- Read symbols or sections, not whole large files, unless required
- Store stable facts in the refactor files, not in chat

### Never do

- Paste long stdout back into the chat when a short summary is enough
- Re-run broad project scans in the implementation thread
- Keep negotiating architecture in the same thread as heavy implementation
- Use the chat as the only record of scope and decisions
- Treat subagent raw output as final truth without rewriting it into claims

## Escalation Rules

Return to planning if any of these happen:

- a public interface must change
- a cross-layer dependency appears
- a new subsystem becomes in-scope
- the implementation thread starts needing broad project rediscovery
- the current thread starts restating architecture because the written baseline is no longer sufficient

## Completion Criteria

A large refactor is not complete until:

- `architecture-baseline.md` reflects the final intended structure
- `current-brief.md` matches the implemented scope
- `decision-log.md` captures the major tradeoffs
- `open-risks.md` is either empty or explicitly accepted
- `verification-checklist.md` is completed with evidence
- `evidence-ledger.md` contains the claims supporting the final architecture and scope
- `handoff-checklist.md` proves each implementation slice had a closed decision packet
