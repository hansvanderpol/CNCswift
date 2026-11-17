# Contract: Machine Profile

**Consumers**: `CNCToolpath` (limits, clearance height), `CNCGCode` (blocks, tokens, extension), `CNCValidation` (conformance rules), `CNCSimulation` (envelope), `CNCMaterials` (limit intersection), `CNCPipeline` (setup confirmation).

The profile is data. No package may hardcode a dialect token, limit, or block line (FR-015).

## Profile document schema

```json
{
  "profileID": "twotrees-ttc450-pro",
  "displayName": "TwoTrees TTC450 PRO",
  "version": "1.0.0",
  "dialect": "grbl1_1",
  "envelope": { "x": 460.0, "y": 460.0, "z": 80.0 },
  "limits": {
    "maxFeedRate": 800.0,
    "maxRapidRate": 800.0,
    "spindleMin": 5000.0,
    "spindleMax": 8000.0,
    "maxLineLength": 80
  },
  "controllerSetup": {
    "spindleBuffer": { "$30": 8000, "$31": 5000 },
    "rapidRate": { "$110": 800, "$111": 800, "$112": 800 }
  },
  "toolActivation": "spindle",
  "clearanceZ": 10.0,
  "returnZ": 15.0,
  "outputExtension": "nc",
  "startBlock": [
    "G21",
    "G90",
    "G94",
    "G00 Z10.0",
    "M3 S{spindleSpeed}"
  ],
  "stopBlock": [
    "G90",
    "G00 Z15.0",
    "M5",
    "G00 X0 Y0",
    "M30"
  ],
  "supportedCommands": {
    "motion": ["G0", "G1", "G2", "G3"],
    "feedMode": ["G94"],
    "units": ["G20", "G21"],
    "distance": ["G90", "G91"],
    "plane": ["G17", "G18", "G19"],
    "spindle": ["M3", "M5"],
    "program": ["M0", "M1", "M2", "M30"],
    "other": ["G4", "G10", "G28", "G30", "G38.2", "G38.3", "G38.4", "G38.5",
              "G40", "G53", "G54", "G55", "G56", "G57", "G58",
              "G59", "G61", "G80", "G91.1", "G92", "G92.1"]
  },
  "unsupportedCommands": ["G43", "G43.1", "G49", "G93", "M4", "M6", "M7", "$32"]
}
```

## Values fixed by the constitution

| Field | Value | Source |
|---|---|---|
| `envelope` | 460 x 460 x 80 mm | Principle VI |
| `maxFeedRate` | 800 mm/min | Principle VI |
| `maxRapidRate` | 800 mm/min | Principle VI |
| `controllerSetup.rapidRate` | `$110 = $111 = $112 = 800` | Derived: GRBL `G0` ignores `F`, so this is the only enforcement point (research D12) |
| `controllerSetup.spindleBuffer` | `$30 = 8000`, `$31 = 5000` | Technology Stack, machine setup |
| `spindleMin` / `spindleMax` | 5,000 / 8,000 RPM inclusive | Principle VI |
| `dialect` | GRBL 1.1 | Principle VI |
| `outputExtension` | `nc` | Principle VI |
| `clearanceZ` | 10.0 | Start block |
| `returnZ` | 15.0 | Stop block |
| `startBlock` | `G21`, `G90`, `G94`, `G00 Z10.0`, `M3 S{spindleSpeed}` | Principle VI |
| `stopBlock` | `G90`, `G00 Z15.0`, `M5`, `G00 X0 Y0`, `M30` | Principle VI |

`unsupportedCommands` includes `G43`, `G43.1`, and `G49` (tool-length offsets and their
cancellation), `M6` (tool change), `G93` (inverse-time feed, which would invalidate the
`F <= maxFeedRate` rule), `M4` and `$32` (laser/dynamic-power tokens), and `M7` (compile-time
disabled in stock GRBL). `M4` must never appear as a supported spindle command.

## Controller setup is not program content

`controllerSetup` describes machine configuration the operator applies once. It is not emitted, not read back, and not modified by the app (the same rule the constitution states for `$30`/`$31`).

- The main screen displays the required settings and requires an explicit confirmation before generation is enabled (FR-024). `JobSettings.rapidRateConfirmed` carries that state.
- The header records that the rapid rate was controller-set, not that a rate was commanded in the file (FR-081, `contracts/gcode-output.md`).
- A profile whose `controllerSetup.rapidRate` values differ from `maxRapidRate` is rejected at startup as internally inconsistent, rather than silently used.
- The app never sends `$` commands. A generated file containing a `$` setting is a validation error.

## Invariants

1. `startBlock` and `stopBlock` are ordered lists, not sets. Order is part of the contract (FR-019, FR-020).
2. `{spindleSpeed}` is the only substitution in any block; it must be within `[spindleMin, spindleMax]` before substitution, or generation fails (FR-022).
3. `maxLineLength` applies to every line, including comments and header lines (research D8).
4. `version` appears in every generated header so a file can be traced to a profile revision (FR-014).
5. A profile the app does not recognise, or one declaring a dialect other than `grbl1_1`, is rejected at startup rather than used partially.
6. Adding a machine means adding a profile document, never a branch in pipeline code (FR-016).
7. A profile with an empty envelope dimension, a non-positive feed or rapid limit, or an inverted spindle range is rejected at startup.

## Conformance rules used by validation

- Every command word in the emitted program must appear in `supportedCommands`; any word in `unsupportedCommands` fails even if a profile were edited to list it in both sets.
- Coordinates must lie within `envelope` on all three axes, boundary inclusive.
- Feed mode MUST remain `G94`; `G93` inverse-time feed is unsupported, so every `F` word is
  millimetres per minute and must be at most `maxFeedRate`.
- A rapid line (`G0`/`G00`) must not carry an `F` word or an `S` word; there is no rapid rate to validate in the file (FR-024).
- Every `S` word must be within `[spindleMin, spindleMax]`.
- The program must begin with `startBlock` in order and end with `stopBlock` in order, with `M30` as the final line.
- No line may contain a `$` setting command or a laser-mode token; `M4` and `$32` are rejected explicitly (FR-031).
