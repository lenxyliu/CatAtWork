# Runtime state machine and action queue

## State model

The runtime tracks the active body action, current physical pose, queued behavioral intents, animation progress, physical ownership, and session generation. Gaze is a render-layer channel and does not own the body animation.

## Queue contract

- Submitted behavior is an intent, not a pre-expanded transition chain.
- Priority affects which queued intent is selected next. Equal priority preserves FIFO order.
- When the active action finishes, select the next intent first, then compute the pose bridge from the **actual current pose** to that intent's required start pose.
- A generated bridge and its target are atomic: another queued intent cannot be inserted between them.
- The priority queue stores only original intents. A selected intent becomes
  an active atomic plan consisting of zero or more bridges followed by the
  target; the plan's continuation is not returned to priority arbitration.
- Expiry and explicit animation completion both commit the finished
  animation's end pose before selecting and routing the next intent.
- Forced physical chains (`pickup -> thrown/dropped -> landing`) clear stale lower-priority intents and retain ownership until landing completes.
- Durations begin when the selected action actually becomes active, never when it enters the queue.
- Completion updates pose from the actual animation contract; returning to idle uses a legal bridge where necessary.

## Required regression oracles

- A lower-priority intent queued first and a higher-priority intent queued later must still produce a legal pose chain after reordering.
- Equal-priority intents remain FIFO.
- Package/session reset leaves idle active, an empty queue, a known initial pose, zero velocity, and no prior expiry.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Defined dequeue-time routing and atomic bridge semantics. |
| 2026-07-23 | CHG-20260723-010 | Implemented raw-intent queuing, actual-pose dequeue routing and atomic bridge continuations. |
