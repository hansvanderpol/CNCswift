# Phase 1 Data Model: STL to Machine-Ready G-code

**Feature**: `001-stl-to-gcode` | **Date**: 2026-11-17

Entities are described by meaning and validation rule, not by Swift source. Field names are the terms the contracts and tasks use. All lengths are millimetres, all speeds are millimetres per minute, all spindle speeds are revolutions per minute.

Entity names map to the spec's Key Entities and, where Swift types normalise the spelling, the mapping is noted once: **Stock Blank** → `StockBlank`, **Generation Record** → `GenerationRecord`.

## MachineProfile

The single versioned description of the target machine. Read-only at runtime; supplied as data, not code.

| Field | Type | Rule |
|---|---|---|
| `profileID` | stable string | Fixed for the TTC450 PRO; a different machine is a different profile |
| `version` | semantic version | Recorded in every generated file header (FR-014) |
| `dialect` | `grbl1_1` | The only dialect this feature supports |
| `envelope` | X/Y/Z extents | 460 x 460 x 80; boundary inclusive (FR-025) |
| `maxFeedRate` | number | 800; above is rejected, never clamped (FR-023) |
| `maxRapidRate` | number | 800; the rate the controller settings must produce (FR-024) |
| `rapidRateSetup` | list of controller settings | `$110 = 800`, `$111 = 800`, `$112 = 800`; machine setup, never written to the file |
| `spindleRange` | closed range | 5,000-8,000 inclusive (FR-022) |
| `spindleBufferSetup` | list of controller settings | `$30 = 8000`, `$31 = 5000`; existing machine-setup precedent |
| `toolActivation` | `spindle` | Laser activation is out of scope (FR-031) |
| `supportedCommands` | set | The GRBL 1.1 command set; anything outside is not emitted (FR-017) |
| `startBlock` | ordered lines | `G21`, `G90`, `G94`, `G00 Z10.0`, `M3 S<S>` (FR-019) |
| `stopBlock` | ordered lines | `G90`, `G00 Z15.0`, `M5`, `G00 X0 Y0`, `M30` (FR-020) |
| `outputExtension` | `nc` | No other extension is produced (FR-018) |
| `clearanceZ` | number | 10.0, the start block's Z; used for rapid repositioning (FR-039) |
| `maxLineLength` | integer | 80, from GRBL's line buffer |
| `returnZ` | number | 15.0, the stop block's lift |

`rapidRateSetup` is descriptive, not operative. The app documents it, requires operator confirmation, and never reads or writes controller settings.

## Material

A named material the user is carving, carrying recommended cutting bands. Distinct from the stock blank, which carries only dimensions (FR-077).

| Field | Type | Rule |
|---|---|---|
| `id` | stable identifier | Assigned once, never reused |
| `name` | string | Non-empty after trimming; unique within the library |
| `feedBand` | closed range | Both bounds greater than zero, lower not above upper (FR-078) |
| `spindleBand` | closed range | Both bounds greater than zero, lower not above upper (FR-078), and intended for RPM |
| `origin` | `builtIn` \| `user` | Built-ins are read-only and shipped with the app |
| `shippedVersion` | string or none | Set for built-ins so a preset revision is traceable |

A band may sit entirely outside the profile's limits; that is a valid record and an unusable job (FR-080), because a material's real-world recommendation is a physical fact the app must not rewrite. Bands are never clamped at entry.

### Built-in presets (shipped, read-only)

| Name | Feed band (mm/min) | Spindle band (RPM) |
|---|---|---|
| Softwood (pine/basswood) | 600-800 | 7,000-8,000 |
| Hardwood (oak/maple) | 400-600 | 7,000-8,000 |
| MDF | 500-700 | 7,000-8,000 |
| Plywood | 500-700 | 7,000-8,000 |

Exactly four presets ship (FR-077). The values are provisional engineering guidance pending sign-off (research D11), and a fixture asserts the count, the names, and that every band is ordered.

## EffectiveCuttingValues

The resolved feed rate and spindle speed for one job. Produced only by `CNCMaterials`, never by a UI or a planner.

| Field | Type | Rule |
|---|---|---|
| `feed` | number | Inside `material.feedBand ∩ [0, profile.maxFeedRate]` |
| `spindle` | number | Inside `material.spindleBand ∩ profile.spindleRange` |
| `source` | `cutterPrefill` \| `nearestBound` \| `userChoice` | How the prefilled value was derived |
| `confirmed` | boolean | False until the user confirms; an unconfirmed value MUST NOT be applied (FR-079) |

**Resolution rule** (FR-079): for each value, intersect the material band with the profile limit. If the cutter's recorded value lies inside the intersection, prefill it (`cutterPrefill`); otherwise prefill the nearest bound (`nearestBound`). The user may confirm any value inside the intersection (`userChoice`). A value outside the intersection is rejected, not clamped.

**Empty intersection** (FR-080): if either intersection is empty, resolution returns a typed `.noOverlap` naming the material, the band, and the ceiling or floor it cannot satisfy. No job can be built from it, and no file is written.

## STLModel

The decoded source geometry and what the user confirmed about it.

| Field | Type | Rule |
|---|---|---|
| `sourceURL` | file reference | Read-only; the app never writes to it |
| `encoding` | `ascii` \| `binary` | Detected from content, not extension (D4) |
| `triangleCount` | integer | Must be greater than zero (FR-003) |
| `bounds` | axis-aligned box | In model units before confirmation |
| `unitsConfirmed` | boolean | Must be true before planning (FR-005) |
| `orientationConfirmed` | boolean | Must be true before planning (FR-005) |
| `appliedScale` | number or none | Only set by explicit user action (FR-006) |
| `isManifold` | boolean | False is a rejection (FR-003) |
| `degenerateTriangleCount` | integer | All degenerate is a rejection (FR-003) |
| `features` | derived | Smallest feature relative to the selected cutter (FR-041) |

## Mesh and Triangle (internal geometry)

Vertices in model space, converted once through the explicit transform to machine space (FR-012). The mesh carries an index of triangles for BVH construction. No entity here is persisted.

## StockBlank

| Field | Type | Rule |
|---|---|---|
| `width` (X) | number | Greater than zero, at most 460 (FR-010) |
| `depth` (Y) | number | Greater than zero, at most 460 (FR-010) |
| `height` (Z) | number | Greater than zero, at most 80 (FR-010) |
| `origin` | constant | Front-left top corner; X0 Y0 at that corner, Z0 at the top surface (FR-009) |

The model must fit inside the blank on all three axes, or generation is refused (FR-011).

## Cutter

One stored mill cutter. `type` is a closed enumeration and owns the dimensions that define it; there is no shared `diameter` field (FR-044, FR-046).

| Field | Type | Rule |
|---|---|---|
| `id` | stable identifier | Assigned once, never reused (FR-042) |
| `name` | string | Non-empty |
| `type` | `flat` \| `ballNose` \| `vBit` | Closed set (FR-044) |
| `shankDiameter` | number | Greater than zero, at least the cutting diameter (FR-045) |
| `cuttingLength` | number | Greater than zero; bounds the maximum depth per pass (FR-033) |
| `fluteCount` | integer | At least 1 and at most 8 (FR-048) |
| `feedRate` | number | Greater than zero and at most 800 (FR-048); a starting value, not the emitted one |
| `spindleSpeed` | number | Within 5,000-8,000 inclusive (FR-048); a starting value, not the emitted one |
| **flat only** `cuttingDiameter` | number | Greater than zero |
| **ball nose only** `ballDiameter` | number | Greater than zero |
| **V-bit only** `includedAngle` | number | Greater than zero and less than 180, and able to form a cone |
| **V-bit only** `tipDiameter` | number | At least zero and no wider than `shankDiameter` |

Type-specific rules (FR-046, FR-048):

- A record may not carry another type's dimension as a substitute; the decoder rejects unknown fields for the declared type.
- A tip wider than the shank is rejected at entry.
- An included angle that cannot form a cone is rejected at entry.
- Every rejection happens at entry, never at generation time (FR-048).
- A missing required attribute blocks generation with a message naming the attribute; no default is substituted (FR-049).

**Cutter lifecycle**: `draft` (being edited, not persisted) → `valid` (passes entry validation) → `stored` (written to the library) → `deleted`. A cutter never transitions from `draft` to `stored` without passing validation.

## CutterLibrary

| Field | Type | Rule |
|---|---|---|
| `schemaVersion` | integer | Present in every stored document (FR-051) |
| `cutters` | array of Cutter | Identifiers unique across the array |
| `location` | derived | Application Support, sandboxed container (FR-051) |

**Library states**: `absent` (start empty, report it) → `loaded` → `migrated` (when the stored version is older) → `saved`. A file newer than the app's schema enters `refused`, is reported, and is left byte-identical (FR-053). A corrupt file enters `corrupt`, is reported with its path, and a backup is preserved (FR-054). No state silently discards records.

**Change notification**: the store publishes `.saved`, `.deleted(id:)`, and `.reloaded` events on an `AsyncStream`. Consumers re-resolve by identifier; the stream carries no mutable record data, so the persisted document stays the only contract (FR-058, research D14).

## MaterialLibrary

| Field | Type | Rule |
|---|---|---|
| `schemaVersion` | integer | Same versioning contract as the cutter library (FR-077 persistence) |
| `materials` | array of Material | User-defined records only; presets are code-shipped and merged in at load |
| `location` | derived | Application Support, sandboxed container |

**Library states**: `absent` (built-ins only, report it) → `loaded` → `migrated` → `saved`; `refused` and `corrupt` behave exactly as the cutter library does. A user material may not shadow a preset name; a duplicate name is rejected at entry rather than silently renaming either record.

## JobSettings

The confirmed choices binding a model, stock, material, and cutter to one job.

| Field | Type | Rule |
|---|---|---|
| `model` | STLModel | Units and orientation confirmed |
| `cutterID` | identifier | Must resolve to a stored cutter (FR-060) |
| `materialID` | identifier | Must resolve to a built-in preset or a stored user material |
| `stock` | StockBlank | Inside the envelope |
| `effective` | EffectiveCuttingValues | Resolved and confirmed (FR-079) |
| `stepover` | number | Greater than zero and below the cutter's cutting diameter (FR-035) |
| `maxDepthPerPass` | number | Greater than zero and at most the cutter's cutting length (FR-033) |
| `finishingAllowance` | number | At least zero and less than the stock height (FR-034) |
| `rapidRateConfirmed` | boolean | False blocks generation until the operator confirms the controller settings (FR-024) |
| `confirmed` | boolean | Suggested values are prefilled but not applied until confirmed (FR-037) |

## Toolpath

| Field | Type | Rule |
|---|---|---|
| `roughingLayers` | ordered layers | Descending Z, each at most `maxDepthPerPass` deep |
| `finishingPasses` | ordered raster passes | At `stepover` spacing across the model footprint plus exactly one cutter radius (FR-038) |
| `moves` | ordered moves | Each is `rapid` or `cut`; rapids never enter material (FR-039) |
| `feedRate` | number | The job's confirmed effective feed; applied to every cutting move (FR-040) |
| `bounds` | axis-aligned box | Must lie inside the envelope and the stock |

Every move carries `from`, `to`, and `mode`. Toolpath shape is a pure function of model, cutter geometry, stock, and job settings, so a geometry change invalidates it (FR-036). Re-planning is required when the cutter geometry, the material, or a confirmed effective value changes.

## GCodeProgram

| Field | Type | Rule |
|---|---|---|
| `header` | GenerationRecord | Fixed field order; the only variable field is the generation timestamp |
| `lines` | ordered lines | Start block, body, stop block; each at most 80 characters |
| `validation` | ValidationReport | Must contain no error-severity finding before writing (FR-026) |
| `text` | rendered output | UTF-8, `\n` endings, invariant number formatting |

## GenerationRecord (file header)

Cutter identifier, cutter name, cutter type, every attribute value actually used, the material name, both material bands, the confirmed effective feed and spindle, the rapid-rate basis (controller settings, not a program word), profile ID and version, job settings, declared units, origin, any confirmed scale, model file name, and one ISO-8601 UTC generation timestamp (FR-029, FR-081).

## ValidationReport

| Field | Type | Rule |
|---|---|---|
| `findings` | array | Each has severity, line number, rule identifier, and message |
| `severity` | `error` \| `warning` | Any `error` blocks writing |
| `correlationID` | identifier | Matches the log record (FR-067) |
| `program` | parsed program | The validated text plus its parsed moves, so simulation consumes what was checked (FR-065) |

Checked: dialect conformance, envelope containment, feed ceiling, spindle range, block presence and order, `M30` final, `M5` before the origin return, no feed word on any rapid, and the 80-character line limit.

## SimulationResult

| Field | Type | Rule |
|---|---|---|
| `heightmap` | grid of Z values | Stock-space resolution recorded with the result |
| `resolution` | number | Documented; drives preview fidelity |
| `removedVolume` | number | Derived; not used as a pass/fail signal |
| `violations` | array | Envelope and limit findings surfaced before writing (FR-064) |
| `cancelled` | boolean | Cancellation is distinct from failure (FR-066) |

Rapids never modify the heightmap (FR-063). The result is computed from the validated program, not from the emitter's toolpath object (FR-065).

## Relationships

- `MachineProfile` 1 — * `JobSettings`: every job is evaluated against exactly one profile version.
- `CutterLibrary` 1 — * `Cutter`: the library is authoritative; generation holds a read-only reference.
- `MaterialLibrary` 1 — * `Material`: presets merge with user materials at load; each job references exactly one.
- `Material` 1 — * `JobSettings`, `Cutter` * — * `JobSettings`: one material and one cutter per program, because the dialect has no tool change.
- `JobSettings` 1 — 1 `EffectiveCuttingValues` 1 — 1 `Toolpath` 1 — 1 `GCodeProgram` 1 — 1 `SimulationResult`.
- `GCodeProgram` → `GenerationRecord`: records what was used, so the file stays reproducible after the cutter or material is edited.

## Job state transitions

```text
empty
  -> modelLoaded            (STL decoded and accepted)
  -> configured             (cutter and material selected, stock entered, settings confirmed)
  -> blocked                (any validation error, unconfirmed effective value, or
                             unconfirmed rapid-rate setup; returns to configured on fix)
  -> validated              (program parses and conforms)
  -> simulated              (preview available)
  -> written                (file atomically on disk)
  -> cancelled              (from any long step; no file)
```

`blocked` is reachable from `configured`, `validated`, and `simulated`, because a cutter or material edit, an emptied intersection, or an envelope breach discovered late must prevent writing. `written` is terminal for a job; regenerating creates a new job state from `configured`.
