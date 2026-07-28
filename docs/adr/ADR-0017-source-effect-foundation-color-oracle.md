# ADR-0017 — Bind foundation color to the accepted source-effect oracle

- Status: proposed
- Date: 2026-07-28
- CHG: CHG-20260728-001
- ISSUE: ISSUE-016, ISSUE-026; GitHub #10, #21
- Supersedes: ADR-0016 foundation color-target choice only

## Context

ADR-0016 correctly requires authored sRGB RGBA8 straight-alpha pixels and an
identity source-to-atlas conversion. The first B4 foundation slice added a
separate 80% material-palette pull before those authored pixels entered the
canonical package. Candidate 9 passed that internally consistent target.

The later interaction native review supplied stronger visual evidence: the
generated effect-sheet appearance is the accepted target, while the
palette-normalized native appearance is not. The native test's seated frame is
byte-identical to production `idle/000.png`, and its Metal texture/drawable
sRGB sources are byte-identical to the repository. On accepted `waiting`
source-effect pose 0, the existing pull changes 68,203/68,749 visible pixels
and produces source-to-authored ΔE00 7.225664 for dark material.

An interaction-only exception would flash at the required exact seated
endpoints. Conversely, preserving every raw source-effect pixel without any
normalization fails 36 accepted B2 adjacent/batch material observations in
the foundation bridges.

The first proposed replacement used an equal-weight per-pixel source/target
pull. It passed median ΔE and B2, but direct native review rejected the
result because fur detail was visibly flattened. Content-matched measurement
confirmed that same-material local L* gradient RMS fell to `0.505941` light,
`0.496541` warm and `0.522526` dark relative to the accepted effect source.
Median color alone is therefore not a sufficient source-effect oracle.

## Decision

Adopt one governed source-effect-to-authored color oracle for the entire
foundation and later B4 action families.

- The accepted source-effect reference is bound by full-file SHA-256 and its
  recorded light, warm and dark material measurements. The oracle rejects a
  different source file.
- Normalize each governed material with one package-global
  detail-preserving rule. The target sRGB medians are measured from the
  accepted source effect: light `[250, 225, 212]`, warm `[221, 157, 125]`,
  and dark `[53, 13, 3]`.
- The low-frequency base uses source weight 2 and target weight 3. A
  deterministic summed-area calculation measures the same-material local RGB
  mean in a radius-2 / 5×5 neighborhood without crossing alpha or material
  boundaries. Seven tenths of the source pixel's residual from that local
  mean is added back to the base. Every division uses nearest-integer
  ties-to-even rounding and the final channel is clamped to RGBA8.
- The classification thresholds, alpha minimum, neighborhood, base/detail
  weights and rounding are declared data. The implementation may not tune
  them per action or frame.
- The accepted source-effect sample must retain its canvas and alpha bytes,
  and its normalized light, warm and dark medians must each remain within
  CIEDE2000 ΔE00 3 of the source effect.
- The oracle separately measures horizontal/right and vertical/down
  same-material adjacent L* gradients on the frozen source coordinates.
  Authored/source RMS must remain within `[0.98, 1.05]` independently for
  light, warm and dark materials; this prevents both detail suppression and
  artificial oversharpening.
- The production rebuild uses the preserved candidate-9 source poses and
  changes color only. Scale, canvas, safe margin, root/support, identity,
  pose/bridge, component, deformation, absolute facing, no-resize and
  source-to-atlas identity rules remain the ADR-0016 contract.
- Atlas packing still performs no color conversion: the corrected authored
  sRGB bytes are copied exactly and source/atlas RGBA digests must match.

## Consequences

The dark face/ear material remains faithful to the user-accepted generated
appearance instead of being pulled toward the rejected lighter frozen mask.
The detail-preserving correction satisfies the accepted B2 continuity gates
without using texture suppression as its continuity mechanism. On the frozen
effect sample, material ΔE00 is `0.826423` light, `2.947122` warm and
`0.389036` dark while local-gradient retention is `1.010780`, `0.990451` and
`1.013864`, respectively.

All 216 foundation frames require a deterministic color-only rebuild and
native re-acceptance. The blocked interaction checkpoint remains preserved
and must not resume until this prerequisite is reviewed and merged; its
foundation digest and color provenance will then need an explicit later
update.

The native acceptance is intentionally limited to this color decision.
Animation timing and cross-action scale remain governed by their own Issue,
contract and batch boundaries; neither is evidence for or against this color
oracle.

## Rejected alternatives

- Keeping the candidate-9 target treats an internally passing oracle as more
  authoritative than direct native user rejection.
- Changing the Metal renderer is unsupported by the byte-identical sRGB source
  evidence and would alter every asset rather than the authored defect.
- An interaction-only color exception breaks exact endpoint continuity.
- Identity/no normalization preserves the sampled effect exactly but fails 36
  accepted foundation B2 material observations.
- An equal-weight per-pixel pull passes the median-color gates but retains
  only about half of the accepted local fur gradients and failed direct
  native user review.
- Frame-local or action-local median offsets are automatic but can color-pump
  across pose composition changes; an isolated spike still left eight B2
  failures and was not adopted.
- Per-action or per-frame hand tuning is not deterministic, is difficult to
  review, and would reintroduce batch-dependent color drift.
