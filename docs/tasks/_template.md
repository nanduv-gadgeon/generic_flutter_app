# Task <plan-id> – <name>

Copy this file to `docs/tasks/<plan-id>-<name>.md` and fill in every section before planning.

## Goal

<!-- One or two sentences: what the user or team gets when this task is done. -->

## Requirements covered

<!-- Item numbers from docs/requirements.md, e.g. "1.1–1.3 App start". -->

-

## Scope

**In scope**

-

**Out of scope**

-

## Interfaces / files expected

<!-- Service interfaces, classes and files this task adds or changes, with their layer. -->

| File | Layer | Purpose |
| --- | --- | --- |
|  |  |  |

## Phase behaviour

| isCloud | Behaviour |
| --- | --- |
| false (Phase 1) | <!-- Must make zero network calls. --> |
| true (Phase 2) | <!-- Usually an empty hook marked // TODO(phase2). --> |

## Acceptance criteria

- [ ]
- [ ] Unit tests added (mocktail); `flutter analyze` and `flutter test` are clean
- [ ] Every new button and spinner has a Semantics label

## Test data (fake data only)

<!-- Synthetic values only. Never use real users, real health readings, real device IDs or real credentials. -->
