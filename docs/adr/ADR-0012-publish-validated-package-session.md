# ADR-0012 — Publish a validated package as a runtime session

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-011
- ISSUE: ISSUE-002

## Context

Manifest lookup silently substituted `idle`, package pose metadata was not
authoritative, density metadata was ignored, and `nextAnimation` was never
executed. PetWindowController then replaced only package/render fields during
a switch, allowing the previous pet's behavior, velocity and timers to leak
into the new package.

## Decision

Compile each validated manifest into one immutable runtime contract containing
exact capabilities, deterministic semantic fallbacks, derived pose profiles,
available pose bridges, next-animation edges and density-normalized canvas
scale. Behavior resolves against that contract before queueing.

Publish the contract, manifest and resource root as one session boundary only
after inspection succeeds. Increment the session generation and reset all
package-owned runtime, input, animation, physics, timing and renderer
transients together. Preserve the prior valid session when inspection fails.

Use `collisionRect ?? trimRect` as the sole fallback interaction geometry.

## Consequences

Missing actions become observable suppression rather than disguised idle.
Packages with different source density render at stable world size, custom
pose metadata participates in routing, and one-shot continuation becomes
deterministic. Session reset remains centralized in the controller until
PetRuntimeState/reducer extraction; that later change must preserve this
publication boundary and its regression evidence.
