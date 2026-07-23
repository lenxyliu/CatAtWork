# Stable IDs for the frozen 2026-07-23 issue baseline

This is an identity map, not a new claim of verification. Exact descriptions, causes, states and evidence remain frozen in root `ISSUE-CLASSIFICATION.md`; root `COMPLETION-AUDIT.md` records the same-date completion claims. “Code fixed” claims that lack a content-matched immutable TR remain `fixed-unverified` or `device-pending` under the new vocabulary.

Each migrated `ISSUE-NNN` has a matching independent `docs/issues/badcases/BC-NNN.md`. These records preserve the frozen reproduction claim and evidence gap; they do not fabricate a new execution.

| Stable ID | Frozen section/row summary | Migrated status |
| --- | --- | --- |
| ISSUE-100 | landing sequence repeats crouch / pose reversal | device-pending |
| ISSUE-101 | thrown fragments and direction jumps | device-pending |
| ISSUE-102 | jump/startled invalid prone frames and scale changes | device-pending |
| ISSUE-103 | green edges, cropped fur and wide-pose clipping | device-pending |
| ISSUE-104 | runtime fur/iris color mismatch | device-pending |
| ISSUE-105 | resting physics emits repeated landing | fixed-unverified |
| ISSUE-106 | high placement emits landing twice | fixed-unverified |
| ISSUE-107 | competing sources reset body animation | fixed-unverified |
| ISSUE-108 | incompatible pose takes over after landing | device-pending |
| ISSUE-109 | ordinary system state interrupts too often | fixed-unverified |
| ISSUE-110 | work/meeting/music/idle context discarded | fixed-unverified |
| ISSUE-111 | pointer pass triggers chase/petting | device-pending |
| ISSUE-112 | interaction direction not locked | device-pending |
| ISSUE-113 | right-click menu race | device-pending |
| ISSUE-114 | autonomy stops without input/display callbacks | device-pending |
| ISSUE-115 | micro-motion blocked by gaze/interest | device-pending |
| ISSUE-116 | animation timing too fast | device-pending |
| ISSUE-117 | 60/120 Hz movement appears stepped | device-pending |
| ISSUE-118 | transparent window shows black box | device-pending |
| ISSUE-119 | pet scale lacks stable control | device-pending |
| ISSUE-120 | body scale changes between actions | device-pending |
| ISSUE-121 | safe canvas lifts feet from desktop ground | fixed-unverified |
| ISSUE-122 | multiple old application processes/pets coexist | device-pending |
| ISSUE-123 | running build/asset/action is not visible | fixed-unverified |

No retroactive per-case facts are invented here. Before changing a migrated issue, create a dedicated `BC-<new ID>` from reproduced current behavior and link this stable ISSUE ID, or create a superseding ISSUE when scope materially differs.
