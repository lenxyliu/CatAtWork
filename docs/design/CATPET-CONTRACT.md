# `.catpet` package contract

## Supported contract

- `formatVersion` selects contract semantics; unsupported versions fail explicitly.
- `pixelsPerBodyUnit` is finite and positive and defines the world scale shared by every frame.
- Animation IDs are package capabilities. Runtime intent maps to a semantic capability and resolves once per session.
- Every animation declares or derives a valid `startPose` and `endPose`; pose names must belong to the supported pose vocabulary.
- `nextAnimation`, when present, points to a real animation and is honored after a one-shot completes unless a stronger runtime transition owns completion.
- A missing optional capability follows a documented fallback table. It must never silently turn into idle merely because a lookup failed.
- Required baseline capability: `idle`. Interactive/physical capabilities may be declared unsupported; UI and behavior selection must then not offer them.
- `collisionRect` is preferred. If absent, hit testing falls back to `trimRect`, not the full transparent canvas.

## Session load

Inspect and validate all metadata and referenced resources before publishing a session. Publishing increments a session generation and atomically resets runtime state and cache namespace. A failed load preserves the previous valid session.

## Compatibility

Legacy packages lacking poses are migrated through deterministic per-animation defaults. Unknown runtime behaviors are reported as unavailable; malformed package references are rejected at import.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Defined capabilities, pose/next semantics, scale, fallback and session reset. |

