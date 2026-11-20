# Golden G-code Output

These `.nc` files are the reviewed production-output fixtures for T074. Each one is emitted by
`CNCGCode.GCodeEmitter` from the contract-sourced toolpath in `EmitterFixture`, then checked by
`CNCValidation.GRBLValidator` before being committed.

Fixed inputs:

- `generatedAt`: `2026-11-17T09:12:44Z`
- Cutter: `8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10`, `6mm flat`
- Material: `Hardwood (oak/maple)`, feed band `400.000-600.000`, spindle band `7000-8000`
- Effective feed/spindle: `600.000` mm/min and `8000` RPM
- Rapid rate: controller setting `800` (`$110-$112`), never a program word
- Scale: `1.000`

The five files mirror the five reference STL names from `Fixtures/stl/`. Only the `; model:` header
row and derived output filename differ between them. `Packages/CNCGCode/Tests/GoldenFileTests.swift`
re-emits each file and compares the bytes, so any emitter change requires an explicit review and
fixture refresh.

## Pipeline-level golden (T121–T124, C1)

`generation/footprint-margin-relief-demo-binary.nc` is a second kind of fixture: it is generated
from the real `Fixtures/stl/relief-demo-binary.stl` through `STLDecoder` → explicit placement with
one 3.000 mm cutter radius of margin → `ToolpathPlanner` → `GCodeEmitter`, not from a hand-authored
toolpath. It protects FR-038 / VS-1: the cutter centre region starts at X0/Y0, spans 0–106.000 mm
on both axes inside a 108 x 108 x 70 mm stock, and is never clipped or rescaled (FR-011, FR-025).

Fixed inputs:

- `generatedAt`: `1970-01-01T00:00:00Z` (`Date(timeIntervalSince1970: 0)`)
- Cutter: `8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10`, benchmark 6 mm flat, cutting length 79 mm
- Material: `Hardwood (oak/maple)`; effective feed/spindle `600.000` mm/min and `8000` RPM
- Stock: `108.000 x 108.000 x 70.000` mm; stepover `4.000`, depth per pass `5.000`, allowance `0.500`
- Scale: `1.000`; rapid rate: controller setting `800` (`$110-$112`), never a program word
- SHA-256: `09c3453b6b0128263050b6cc1d01ca4f272e13a0eca4016e219d67309a0403aa`

Production-output review, 2026-11-20: the full 1,715-line program was inspected for the fixed header
values, 7-bit ASCII, the 80-character line limit (maximum 46), the profile start/stop blocks with
`M30` last, non-negative X/Y within the stock, and `GRBLValidator` result `findings=0` with no
errors. See `specs/001-stl-to-gcode/validation-evidence.md` for the linked evidence.

`Packages/CNCPipeline/Tests/GenerationGoldenTests.swift` re-generates and compares the bytes.
`Scripts/update-golden.sh` writes a candidate only to gitignored `Fixtures/gcode/.received/` and
prints `diff -u`; promotion requires a fresh review and is always a manual copy. `Scripts/ci.sh`
fails if a tracked golden changes or a review candidate is tracked.
