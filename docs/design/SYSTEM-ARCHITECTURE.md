# System architecture

## Intent

CatAtWork is split into a deterministic, platform-neutral runtime and a thin macOS adapter. Core owns state transitions and package semantics; AppKit/Metal own events, windows, clocks, and rendering I/O.

## Target boundaries

- `CatAtWorkCore`: `PetRuntimeState`, events/reducer, action selection, pose routing, animation progress, physics, package model and validation. It must not import AppKit.
- `CatAtWork`: App lifecycle, permissions, system/pointer adapters, background package loading, display-link scheduling, window placement, and Metal rendering.
- `PetWindowController`: an adapter that translates AppKit input to runtime events and applies runtime effects. It is not a second state store.
- `PetStore`: package catalog and session selection. Import work occurs off the main actor; only published UI state is main-actor isolated.

## Invariants

1. There is one authoritative runtime state for behavior, pose, queue, animation, physics ownership, and package session identity.
2. A package switch is a session boundary and resets queue, animation time, pose, velocity, drag/pointer/autonomy transient state, and texture cache namespace.
3. Package and image I/O never runs synchronously on the main actor.
4. Production asset identity is content-addressable through repository/Release checksums.
5. Platform integration is tested through events and effects rather than by duplicating core decisions in AppKit.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Established target module boundaries and single-state invariant. |
| 2026-07-23 | CHG-20260723-011 | Made validated package publication an atomic controller session boundary pending the full runtime reducer extraction. |
| 2026-07-23 | CHG-20260723-014 | Extracted `PetRuntimeState` reducer ownership for contract, behavior, animation, physics and session generation; AppKit transients remain adapter-owned. |
