# Quickstart: STL to Machine-Ready G-code

**Feature**: `001-stl-to-gcode` | **Date**: 2026-11-17

A validation and run guide. It states what to run and what must be true; it does not restate implementation detail already fixed by [spec.md](./spec.md), [data-model.md](./data-model.md), or [contracts/](./contracts/).

## Prerequisites

| Requirement | Value | Notes |
|---|---|---|
| macOS | 27.0 or later | Verified here: 27.2.1 |
| Architecture | arm64 | Verified |
| Swift toolchain | 6.4 or later | Verified: 6.4.2 |
| Xcode | **not required** | `xcodebuild` is unavailable on this machine; the build is SPM-only (research D1) |
| Third-party tools | none | `swift format` and `codesign` ship with the Command Line Tools |
| Controller settings | `$110`, `$111`, `$112` = 800; `$30` = 8000, `$31` = 5000 | Machine setup, applied once outside the app (research D12) |

## Setup

```bash
cd /Users/hans/projects/CNCswift
swift build
```

Expected: the workspace builds with zero warnings under Swift 6 language mode with complete concurrency checking.

## Test commands

Swift Testing needs the macro plugin path because Command Line Tools keeps it in a subdirectory SwiftPM does not search (research D2).

```bash
PLUGIN="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
swift test -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN"
```

Expected: every package's tests run and pass. A bare `swift test` fails with `plugin for module 'TestingMacros' not found` — that toolchain artifact is not a test failure.

## Format check

```bash
swift format lint --recursive Packages App
```

Expected: no findings. This gate is part of the definition of done (constitution, Development Workflow).

## Run

```bash
Scripts/make-app.sh
open .build/CNCswift.app
```

Expected: the app launches with a main screen carrying three panels and a Cutter Library command that opens the modal.

## End-to-end validation scenarios

Each scenario proves a success criterion from the spec. All are runnable without the machine connected; the controller is replaced by an independent reading of the emitted file.

### VS-1 — Happy path: STL to `.nc` (SC-001, SC-002, SC-003, SC-013)

1. Ensure the cutter library contains one valid flat cutter recorded at 750 mm/min and 8,000 RPM.
2. Load `Fixtures/stl/relief-demo-binary.stl`.
3. Confirm units as millimetres and orientation as Z-up.
4. Select the built-in **Hardwood (oak/maple)** material.
5. Enter a stock blank inside the envelope, e.g. 200 x 150 x 30.
6. Observe the feed prefills at 600 mm/min (the band's upper bound, because the cutter's 750 lies outside 400-600) and the spindle prefills at 8,000 RPM.
7. Confirm both values and confirm the rapid-rate controller settings.
8. Confirm stepover, maximum depth per pass, and finishing allowance.
9. Generate and save.

Expected:

- Exactly one file is written, extension `.nc`.
- Its first five lines are `G21`, `G90`, `G94`, `G00 Z10.0`, `M3 S8000` in that order.
- Its last five lines are `G90`, `G00 Z15.0`, `M5`, `G00 X0 Y0`, `M30`, and `M30` is last.
- No line exceeds 80 characters.
- No `G0` line carries an `F` word.
- Every `X`/`Y`/`Z` is inside 460 x 460 x 80; every `F` is at most 800.
- The header carries `cutter-feed: 750.000`, `feed: 600.000`, the material name, and both bands, so the prefill substitution is visible.

### VS-2 — Determinism (SC-005)

Generate VS-1 twice into different files with the same fixed generation time injected by the test harness, then diff them.

Expected: byte-identical. With different injected timestamps, identical except the `; generated:` line.

### VS-3 — Rejection, not repair (SC-004)

Attempt, in turn: a truncated binary STL, an empty mesh, a non-manifold mesh, a stock of 470 mm in X, a model wider than the stock, a cutter with 4,500 RPM, a feed of 900 mm/min, a material with feed band 900-1,200 mm/min, and a material band with an inverted bound.

Expected: each is refused with a message naming the problem and the fix; no file is written; nothing is clamped, scaled, trimmed into range, or defaulted.

### VS-4 — Start and stop block integrity (SC-003)

Run the emitted file through `CNCValidation`'s standalone check.

Expected: zero findings. Then mutate copies and confirm an error is reported for each: deleting `M5`, reordering `G94` after `G01`, appending `F800` to a `G0 Z10.0` line, and inserting a `$110=800` line.

### VS-5 — 3D preview (SC-012)

Generate VS-1 and inspect the simulation panel before writing.

Expected: the stock appears with the roughing cavity and the finished surface; rapid moves remove no material; the preview completes within 5 seconds of validation for the reference models.

### VS-6 — Cutter edit propagates (SC-007)

Change the selected cutter's recorded spindle speed to 6,000 RPM in the modal, then regenerate without relaunching.

Expected: the cutter-record change reaches the main screen through the store's change stream, the selection survives, the spindle re-prefills inside the material band, the start block carries `M3 S6000`, and the header shows `cutter-spindle: 6000` with the confirmed effective value.

### VS-7 — Library survives upgrade (SC-008)

Load `Fixtures/library/v1.json` with a build whose schema is v2, then `Fixtures/materials/v1.json` with the same build.

Expected: every cutter and user material survives with an unchanged identifier; the original files are preserved as backups; a fixture comparison shows no field drift; the four presets are present and untouched.

### VS-8 — Offline and cancellable (SC-010, SC-011)

Start a large job, cancel it mid-generation, and observe the network.

Expected: no `.nc` file and no temporary file remain; the outcome reads as cancelled, not failed; a network monitor shows zero outbound connections for the whole session.

### VS-9 — Material band has no overlap (FR-080, SC-013)

Create a user material with a feed band of 1,200-1,600 mm/min and a spindle band of 9,000-10,000 RPM, save it, then select it for a job.

Expected: the material saves successfully (the record is valid), and selecting it blocks generation with a message naming the material, the band, and the 800 mm/min ceiling and 8,000 RPM top end that cannot be met. No value is trimmed into range and no file is produced.

## Manual controller check

Out of scope for automation, but recommended once:

1. Set `$110 = 800`, `$111 = 800`, `$112 = 800`, `$30 = 8000`, `$31 = 5000` on the controller.
2. Copy a generated `.nc` to the controller's SD card and inspect it in a sender's preview.
3. Confirm the controller raises no `error:11` (line length) and no `error:20` (unsupported command), and that rapids move at the expected rate.

The app never drives the machine (FR-030) and never sends or changes a controller setting.
