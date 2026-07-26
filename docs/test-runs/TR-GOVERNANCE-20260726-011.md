# TR-GOVERNANCE-20260726-011 — Closure branch command parse failure

- Status: fail
- Date: 2026-07-26T15:15:00Z
- Content-SHA256: efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a
- Commit/Tree: accepted B2 merge `72d2154afbe590654ce5c21be7363d9c67ac267f`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; local Bash
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-004

## Tested content

A read-only search for prior completed handoff patterns followed by the
intended closure-branch creation command.

## Commands

Run `rg` with a double-quoted expression containing literal Markdown
backticks, then create `codex/visual-qa-gates-closure`.

## Passed

None.

## Failed

Bash failed during parsing with `unexpected EOF while looking for matching
\`\`` and `syntax error: unexpected end of file`.

## Skipped

- The `rg` search did not execute.
- The branch-creation command did not execute.
- No file, ref or external state changed.

## Failure analysis

The shell interpreted the literal backtick in the double-quoted search
expression as command substitution syntax.

## Evidence

The terminal preserved both Bash parsing diagnostics and no Git output.

## Retrospective

The retry used a branch-only command without the unsafe search expression and
created the closure branch from the exact accepted merge.
