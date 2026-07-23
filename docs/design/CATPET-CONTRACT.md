# `.catpet` package contract

## Supported contract

- `formatVersion` selects contract semantics; unsupported versions fail explicitly.
- `pixelsPerBodyUnit` is finite and positive and defines the world scale shared by every frame. Runtime canvas scale is
  `userScale * 220 / pixelsPerBodyUnit`, so equivalent pets authored at
  different pixel densities occupy the same desktop size.
- Animation IDs are package capabilities. Exact lookup never falls back.
  Runtime intent maps through the session's semantic fallback table before it
  enters the action queue; an unresolved optional intent is suppressed and
  reported as unavailable.
- Every animation declares or derives a valid `startPose` and `endPose`; pose
  names belong to `seated`, `standing`, `lying`, `hanging`, or `airborne`.
  Missing legacy values use deterministic built-in profiles, with unknown
  legacy animations defaulting to `seated -> seated`.
- `nextAnimation`, when present, points to a real animation and is honored
  after a one-shot completes only when no queued or atomic runtime transition
  has already claimed completion.
- A missing optional capability follows a documented fallback table. It must never silently turn into idle merely because a lookup failed.
- Required baseline capability: `idle`. Interactive/physical capabilities may be declared unsupported; UI and behavior selection must then not offer them.
- `collisionRect` is preferred. If absent, hit testing falls back to `trimRect`, not the full transparent canvas.

## Semantic fallback table

| Requested capability | Ordered fallback | If unavailable |
| --- | --- | --- |
| `runLeft`, `runRight` | same-direction `walkLeft`, `walkRight` | suppress motion |
| `earPet`, `chinPet`, `backPet`, `bellyPet` | `petting`, then `curious` | suppress reaction |
| `wave` | `curious` | suppress reaction |
| `wakeUp` | `getUp` | suppress wake animation |
| `getUp` | `wakeUp` | suppress recovery animation |
| all other optional IDs | none | suppress |

Physical grab/throw is offered only if `pickup`, `thrown`, and `landing` all
exist exactly. Pose routing uses only authored/derived canonical bridge
capabilities; if no legal route exists, the target is suppressed rather than
starting from an incompatible pose.

## Session load

Inspect and validate all metadata and referenced resources before publishing a
session. Publishing increments a session generation and atomically resets:
behavior/pose/queue, player frame time, physics velocity/impact, drag samples
and ownership, pointer recognizer/chase, gaze/petting/direction state,
autonomy/roam timers, deferred events, current frame and renderer cache
namespace. The current window anchor and global system context may be
preserved. A failed load preserves the previous valid session.

## Compatibility

Legacy packages lacking poses are migrated through deterministic per-animation defaults. Unknown runtime behaviors are reported as unavailable; malformed package references are rejected at import.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Defined capabilities, pose/next semantics, scale, fallback and session reset. |
| 2026-07-23 | CHG-20260723-011 | Specified exact lookup, fallback/suppression, pose vocabulary, density-normalized scale, next-action ownership, trim hit bounds and atomic session reset. |
