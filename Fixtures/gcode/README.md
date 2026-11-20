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
