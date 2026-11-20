# Performance evidence — 001-stl-to-gcode

**Feature**: `001-stl-to-gcode` | **Recorded**: 2026-11-20 | **Task**: T112 (SC-001, SC-012)

This file records measured timings. The executable gates remain `Scripts/ci.sh` and the
per-package test suites. Reproduce with:

```bash
PLUGIN="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
swift test --package-path Packages/CNCPipeline \
  -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" --filter benchmark
```

The harness is `Packages/CNCPipeline/Tests/BenchmarkTests.swift`. It uses the real `STLDecoder`,
`ToolpathPlanner`, `GCodeEmitter`, `GRBLValidator` and `ZMapSimulator`; no stage is faked. Wall-clock
durations vary by machine, so only the two success-criteria budgets are asserted in tests.

## SC-001 — decode plus generation on 200,000 triangles

`Fixtures/stl/relief-demo-200k.stl` spans the whole 460 mm bed, so the explicit scale action (0.5)
is applied before planning, exactly as the app requires for an unconfirmed scale.

| Stage | Measured |
|---|---|
| Content-based decode (200,000 triangles) | 0.257 s |
| Plan + render (3,598 moves, 51,553 output bytes) | 0.053 s |
| Independent validation | 0.027 s |
| **Total** | **0.337 s** |

Budget: under five minutes. **PASS** — 0.337 s against a 300 s ceiling.

## SC-012 — preview within five seconds, all five reference models

Timing covers cutter-sweep z-map simulation plus heightmap-to-mesh conversion for each reviewed
golden `.nc` in `Fixtures/gcode/`, which is the validated program text the app hands to the
simulator. 95% of a five-fixture set requires all five passes.

| Reference STL | Preview | Moves | Result |
|---|---:|---:|---|
| `relief-demo-ascii.stl` | 0.006 s | 12 | PASS |
| `relief-demo-binary.stl` | 0.005 s | 12 | PASS |
| `relief-demo-200k.stl` | 0.005 s | 12 | PASS |
| `deep-cavity.stl` | 0.005 s | 12 | PASS |
| `fine-detail.stl` | 0.005 s | 12 | PASS |

**PASS — 5/5** under the five-second budget.

Supplementary real-program measurement: simulating a 3,600-move program generated from the 200k
fixture took **0.559 s**, still well inside the budget. The current program has 3,598 moves after T119;
the committed golden files contain 12 machine moves each, so the table above is a lower-bound
latency check and the real-program figure is the more demanding data point.

## Finding raised by the benchmark — resolved by T119

Generating from a reference STL whose model minimum sits at the machine origin produced 2,715
validation findings in this benchmark: the cutter-radius footprint in `Footprint.make` expanded to
`X-3.000 Y-3.000`, outside the 460 x 460 x 80 mm envelope checked by
`CNCValidation.ValidationRules.envelope`. The reviewed golden files start their moves at
`X10.000 Y10.000`, so the defect was masked by hand-authored fixtures.

T119 clips the swept region to the stock and the machine envelope (FR-038) and corrects
`spindle-before-origin` to inspect the final origin return rather than the first raster rapid through
X0 Y0. Re-running this benchmark on 200,000 triangles gives 3,598 moves, 51,553 output bytes and
**`findings=0`** (decode 0.257 s, generation 0.053 s, validation 0.027 s, total 0.337 s). The timing
evidence above stands — SC-001 measures speed — and the generated program is now committable, so the
automated VS-1 path is unblocked.
