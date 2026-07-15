# How To Run A Large Refactor

## When To Use This

Use this workflow when a refactor:

- spans multiple files or subsystems
- needs more than one implementation slice
- requires repeated design confirmation
- is likely to exceed a safe single-thread context window

If the change is small and can be understood and verified in one short thread, do not use this full process.

## What Success Looks Like

At the end of the refactor:

1. No critical design fact exists only in chat history
2. The implementation still matches the intended architecture
3. No thread becomes a token sink because it keeps carrying all prior exploration, logs, and tool output

## Operating Model

Treat the refactor as two separate systems:

- Files hold durable memory
- Threads execute one bounded step

If a fact must still matter tomorrow, after a thread reset, or to another implementation slice, it belongs in a file under `docs/refactor/<task-name>/`.

If a fact matters only to complete the current local step, it can stay in the current thread.

## What Must Live In Files

These items must not exist only in chat:

- current architecture boundaries
- allowed and forbidden dependency directions
- explicit scope and non-goals
- public interface constraints
- accepted tradeoffs
- unresolved risks
- verification evidence

If one of these appears in a useful chat message, copy the distilled result into the task folder before continuing.

If the fact can change an implementation decision, also assign or reference a `Claim ID` in `evidence-ledger.md`.

## What Can Stay In Chat

These usually do not need to be preserved after the current step:

- temporary hypotheses that were disproved
- short implementation notes
- one-off grep or graph probes
- local editing intent for the current slice
- short summaries of tool output that is already reflected in a task file

## Folder Setup

Create a task-specific folder under `docs/refactor/`, for example:

```text
docs/refactor/<task-name>/
```

Copy these templates into it:

- `architecture-baseline.md`
- `current-brief.md`
- `decision-log.md`
- `open-risks.md`
- `verification-checklist.md`
- `evidence-ledger.md`
- `handoff-checklist.md`
- `subagent-report.md`

## Stage 1: Scout

Goal: understand the current system well enough to define safe boundaries.

### Inputs

- repo
- graph/index tools
- targeted code reads

### Outputs

- `architecture-baseline.md`
- initial `open-risks.md`
- first `Claim ID` entries in `evidence-ledger.md`

### Rules

- Read broadly, summarize narrowly
- Never carry raw graph dumps into later stages
- Record only stable architecture facts
- Every stable fact that shapes scope or architecture must point to a `Claim ID`

### End Condition

Move to the next stage only when you can state:

- what is in scope
- what is out of scope
- what interfaces must not break
- what the main architectural risks are

## Stage 2: Plan

Goal: define the exact refactor slice before touching code.

### Inputs

- `architecture-baseline.md`
- current architectural findings

### Outputs

- `current-brief.md`
- `decision-log.md`
- completed `handoff-checklist.md` for the first implementation slice

### Rules

- Lock the change boundary explicitly
- Write non-goals
- Write success criteria
- Log architecture-level decisions immediately
- Do not let a high-risk constraint enter the brief without an evidence claim behind it

### End Condition

Move to implementation only when a new thread could implement using the brief without rereading the full analysis history.

## Stage 3: Open A Fresh Implementation Thread

Do not keep implementing in the same thread that performed broad exploration and planning.

### New Thread Input

Use only:

- path to the task folder
- short context summary
- `current-brief.md`
- any exact files or symbols to modify

### Example Handoff

```text
Use docs/refactor/<task-name>/current-brief.md and architecture-baseline.md.
Implement only the current slice.
Do not broaden scope.
If an interface or architectural boundary must change, stop and report it instead of improvising.
```

### Rules

- Re-read only the minimum code needed
- Do not rescan the project unless a real blocker appears
- Keep terminal output small and purposeful
- Stop and hand off if the thread starts re-deriving architecture instead of editing code
- Refuse to proceed if the handoff packet lacks claim references for the current slice

## Stage 4: Update Artifacts During Implementation

These updates are mandatory:

- New risk discovered -> update `open-risks.md`
- Architecture-affecting choice made -> update `decision-log.md`
- Scope changed -> update `current-brief.md`
- New architecture or behavior conclusion -> update `evidence-ledger.md`

Chat history is not sufficient evidence of any of the above.

## Thread Handoff Contract

Every new implementation thread should receive only this packet:

- task folder path
- one-paragraph current objective
- exact files or symbols to inspect
- exact acceptance checks
- open risks that affect this slice
- claim IDs that justify the current scope and constraints

If the handoff packet needs more than a short paragraph plus file paths, the previous stage did not compress enough and should be fixed before opening the next thread.

## Stage 5: Revise In A Separate Short Thread

If the implementation is behavior-correct but messy, do not continue the long implementation thread forever.

Open a short follow-up thread for:

- naming cleanup
- function boundary cleanup
- file organization cleanup
- duplication cleanup

Use:

- the diff
- `current-brief.md`
- `decision-log.md`

Do not drag the full original exploration history into this step.

## Stage 6: Verify In A Separate Short Thread

Use `verification-checklist.md` as the source of truth.

### Inputs

- final code state
- diff
- tests
- relevant runtime or manual validation evidence

### Required Checks

- behavior preserved
- interfaces preserved or explicitly changed
- no accidental cross-layer coupling
- risks updated and either closed or accepted

### End Condition

The refactor is not done until the checklist contains evidence, not just unchecked intentions.

## When To Force A New Thread

Open a fresh thread immediately if any of these happen:

- the current thread has already done broad exploration plus planning plus implementation
- token analysis shows repeated high cached-prefix carry-forward
- a single turn becomes very expensive and later turns keep growing
- you are copying or reviewing large tool outputs repeatedly
- the implementation thread starts re-discovering architecture from scratch

Also force a new thread when:

- the current step now needs a different subsystem than the one named in `current-brief.md`
- the next prompt would need to include more than one long log, diff, or graph dump
- you need to restate multiple design decisions that should already be in `decision-log.md`
- you cannot tell which current conclusions are backed by claims and which are still guesses

## Token-Saving Operating Rules

### Prefer

- symbol-level reads over whole-file reads
- summaries over raw output
- one bounded implementation slice per thread
- explicit artifacts over conversational memory

### Avoid

- pasting entire command outputs into the conversation
- carrying code search dumps forward unchanged
- mixing planning and heavy implementation for too long
- reopening the same large context again and again

## Practical Token Thresholds

These are workflow triggers, not hard protocol limits:

- If cached-prefix ratio is repeatedly high, summarize and reset
- If a thread has multiple heavy turns, stop and reopen with a brief
- If tool output dominates context, replace raw logs with summaries

The exact numbers can vary by model and toolchain, but the pattern matters more than the absolute number.

## Subagent Rules

Subagents are useful only when they return compressed findings.

Good subagent tasks:

- identify entrypoints
- trace callers/callees
- list affected files
- summarize testing surface

Bad subagent tasks:

- dump full code files back to the main thread
- paste long command output
- perform broad repeated rediscovery without summarizing

Use a subagent only when it reduces the main thread context. If the subagent returns large raw output, it failed its job.

Rewrite the result into `subagent-report.md` before using it as part of the main decision state.

## Architecture Safety Rules

During a large refactor, no implementation thread is allowed to invent architecture on the fly.

If any of these happen, stop implementation and go back to planning:

- a module boundary must move
- a shared contract must change
- a new dependency direction appears
- the refactor requires coordinated changes across multiple subsystems that were previously out of scope

This is the guardrail for keeping local cleanups from turning into silent architecture drift.

## Minimal Decision Matrix

Use this matrix before every major prompt:

- Need durable fact later: write or update a task file first
- Need only local code understanding for one edit: stay in the current thread
- Need broad reading across another subsystem: open a scout sub-thread or subagent
- Need to change architecture or scope: return to planning
- Need to continue after a heavy turn: summarize, write files, and open a fresh thread
- Need a high-risk conclusion to survive thread reset: create or update a claim first

## Daily Working Pattern

The recommended cadence for a large refactor is:

1. Scout thread -> write baseline and risks
2. Plan thread -> write brief and decisions
3. Implementation thread A -> do one slice
4. Implementation thread B -> do next slice if needed
5. Revise thread -> clean structure
6. Verify thread -> complete checklist

This is intentionally more structured than ordinary coding. The structure is what preserves information and prevents token blow-up.

## Minimal Quick-Start

If you want the shortest version that still works:

1. Copy the 5 templates into `docs/refactor/<task-name>/`
2. Add `evidence-ledger.md`, `handoff-checklist.md`, and `subagent-report.md`
3. Fill `architecture-baseline.md`
4. Fill `current-brief.md`
5. Open a fresh implementation thread using only the brief plus claim references
6. Update decisions, risks, and claims as you go
7. Finish with `verification-checklist.md`
