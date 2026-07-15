# Architecture Baseline

## Refactor Target

- Name: Unity Network Layer Refactor
- Owner: Codex + user
- Date: 2026-07-08
- Evidence Ledger: `evidence-ledger.md`

## System Boundary

- In scope:
  - `NetworkManager`
  - socket transport and connection wrappers
  - protocol encode/decode path
  - message dispatch and Unity main-thread handoff
- Out of scope:
  - gameplay systems consuming network messages
  - protocol wire format changes
  - backend API changes
- Evidence Claim IDs:
  - C-001
  - C-002
  - C-005

## Core Modules

| Module | Responsibility | Depends On | Notes | Evidence Claim IDs |
| --- | --- | --- | --- | --- |
| `NetworkManager` | orchestration and lifecycle | transport, protocol, dispatch | currently overloaded | C-002 |
| `Transport` | connect/send/receive/reconnect | socket primitives | should stay isolated from game logic | C-002 |
| `Protocol` | encode/decode packet payloads | message schema dictionary | wire compatibility is mandatory | C-001 |
| `Dispatch` | route decoded messages to handlers | Unity main thread, subscriptions | ordering guarantees matter | C-003, C-005 |
| `Heartbeat/Reconnect` | liveness and retry policy | transport timers | timing bugs can cause invisible regressions | C-004 |

## Stable Interfaces

- Existing packet format must remain unchanged because backend compatibility is non-negotiable.
- Existing externally visible handler registration shape must remain unchanged because too many gameplay callers depend on it.
- Connection state callbacks must remain logically equivalent because UI and login flow depend on them.
- Evidence Claim IDs:
  - C-001
  - C-003
  - C-005

## Key Data Flow

1. Entry point: `NetworkManager` receives connect / send requests from game-facing callers
2. Processing path: request enters transport layer, packet is encoded, socket send occurs
3. State mutations: connection state, retry state, subscription state, receive buffers
4. Outputs / side effects: decoded messages are marshalled back to Unity-safe dispatch path
5. Evidence Claim IDs:
   - C-002
   - C-005

## Architecture Invariants

- Transport must not learn gameplay semantics
- Protocol compatibility must be preserved
- Message dispatch must remain deterministic relative to current behavior
- Unity-thread-affine work must stay on the Unity-safe side of the boundary
- Evidence Claim IDs:
  - C-001
  - C-003
  - C-005

## Known Problem Areas

- `NetworkManager` mixes orchestration, transport decisions, and dispatch concerns
- Subscription and message routing logic are difficult to reason about in one pass
- Reconnect / heartbeat policy is entangled with broader lifecycle logic
- Testing isolated behavior is hard because responsibilities are not sharply bounded
- Evidence Claim IDs:
  - C-002
  - C-004

## Refactor Pressure

- Why change is needed now:
  - the module is large, coupled, and expensive to reason about safely
- Why not redesign more broadly:
  - protocol and consumer compatibility are more important than idealized architecture purity
- Evidence Claim IDs:
  - C-001
  - C-002
