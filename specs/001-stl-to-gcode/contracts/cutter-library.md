# Contract: Cutter Library

**Producer**: `CNCCuttersStore` | **Consumers**: `CutterLibraryModalUI` (read-write), `MainScreenUI` and `CNCToolpath` (read-only).

The persisted library is the only shared contract between the main screen and the modal (FR-058). Generation consumes it read-only and must never define or default a cutter parameter (FR-043, FR-049).

## Storage

| Property | Value | Reference |
|---|---|---|
| Location | `Application Support/CNCswift/library.json` inside the sandbox container | FR-051 |
| Format | UTF-8 JSON, two-space indent, stable key order, `\n` endings | research D9 |
| Schema version | Integer `schemaVersion` at the document root | FR-051 |
| Write | Temporary sibling + atomic replace through `CNCStorage`, previous file retained as backup | FR-051, FR-054 |
| Load failure | Report path, preserve backup, never discard records | FR-054 |

Atomic write, backup retention, schema stamping, and the migration runner are shared with the material library through `CNCStorage`. Neither store reimplements durability rules.

## Document schema (v1)

```json
{
  "schemaVersion": 1,
  "cutters": [
    {
      "id": "8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10",
      "name": "6mm flat",
      "type": "flat",
      "shankDiameter": 6.0,
      "cuttingLength": 20.0,
      "fluteCount": 2,
      "feedRate": 750.0,
      "spindleSpeed": 8000,
      "cuttingDiameter": 6.0
    }
  ]
}
```

## Type-specific shape

Exactly one shape is valid per type; a record carrying another type's key is rejected (FR-046).

| Type | Required type key | Forbidden substitutes |
|---|---|---|
| `flat` | `cuttingDiameter` | `ballDiameter`, `includedAngle`, `tipDiameter` |
| `ballNose` | `ballDiameter` | `cuttingDiameter`, `includedAngle`, `tipDiameter` |
| `vBit` | `includedAngle` and `tipDiameter` | `cuttingDiameter`, `ballDiameter` |

Common required keys for every type: `id`, `name`, `type`, `shankDiameter`, `cuttingLength`, `fluteCount`, `feedRate`, `spindleSpeed`.

## What `feedRate` and `spindleSpeed` mean

They are the cutter's own starting recommendation, not the value written to a file. Since the material clarification (FR-040, FR-079):

- The emitted feed and spindle come from the job's confirmed `EffectiveCuttingValues`.
- The cutter record supplies the prefill when it lies inside the material band and profile limits.
- A cutter record outside the material band is not an error; the nearest bound is prefilled instead.
- Both the cutter's recorded values and the effective values appear in the header (FR-081), so a reader can see the difference.

## Entry validation

Rejected at entry, never at generation time (FR-048):

| Rule | Condition |
|---|---|
| Positive dimensions | `shankDiameter`, `cuttingLength`, and the type dimension are all greater than zero |
| Flute count | Integer, at least 1, at most 8 |
| Shank dominance | `shankDiameter >= maxCuttingExtent`, where `maxCuttingExtent` is `cuttingDiameter` (flat), `ballDiameter` (ball nose), or `tipDiameter + 2 * cuttingLength * tan(includedAngle / 2)` (V-bit); `tipDiameter <= shankDiameter` alone is insufficient |
| Cone validity | For `vBit`, `0 < includedAngle < 180` |
| Tip width | For `vBit`, `tipDiameter >= 0` and `tipDiameter <= shankDiameter` |
| Feed ceiling | `0 < feedRate <= 800` |
| Spindle range | `5000 <= spindleSpeed <= 8000` inclusive |
| Identifier | Stable, unique across the array, immutable after assignment |
| Name | Non-empty after trimming |

A failed rule yields a typed error naming the field and the limit; nothing is persisted (FR-048).

## Generation preflight (FR-033, FR-049)

Before generation, `CNCToolpath` blocks when `stock.height > cutter.cuttingLength` and reports
the required cutting length. This is a generation rule, not an entry rule, because the stock is
unknown when the cutter is saved. FR-033 still bounds each individual roughing layer and
finishing pass by `maxDepthPerPass`.

## Migration contract

- On load, a document older than the app's schema is migrated forward through each intermediate version in order.
- Every migration step is covered by a fixture of the prior version and a fixture of the expected result (FR-052).
- No step may drop a record or silently alter a value. A migration that cannot preserve a record must abort and leave the original file untouched.
- A document with a `schemaVersion` newer than the app supports enters `refused`: the app reports the version it found, does not modify the file, and does not run a partial load (FR-053).
- The backup produced by the atomic replace is the recovery path for a failed migration and is never deleted automatically.

## Change notification (FR-060, research D14)

`CNCCuttersStore` is an actor exposing:

```swift
public enum LibraryChange: Sendable, Equatable {
    case saved
    case deleted(id: Cutter.ID)
    case reloaded
}

public var changes: AsyncStream<LibraryChange> { get }
```

Rules:

- The composition root creates exactly one store and injects it into both presentation modules. Neither module constructs its own store for shared use.
- A change event reports **what changed**, never the record itself, so the persisted document remains the only source of truth.
- `MainScreenUI` re-resolves its selected cutter identifier after every event and clears the selection when it no longer resolves, then blocks generation until another stored cutter is chosen (FR-060).
- The modal publishes after a successful atomic save, not before, so a failed write cannot produce a phantom event.
- The stream is buffered per consumer and drops nothing that was published while a subscriber was between suspensions; a dropped event would leave a stale selection.
- No shared mutable object, no `NotificationCenter`, no cross-module view reference (FR-057, FR-058, FR-059).

## Read-only consumption rules

- `CNCToolpath` and `CNCGCode` receive an immutable cutter value, not the store.
- Deleting the selected cutter clears the main screen's selection and blocks generation until another stored cutter is chosen (FR-060).
- Saved work and generated headers reference cutters by `id`; copied attribute values are never treated as authority (FR-050).
- A geometry change invalidates any cached toolpath for that cutter; nothing is reused across a change (FR-036).

## Cross-module import rule

Both presentation modules may import the cutter library, shared geometry, and shared persistence packages. Neither may import the other's views or internal types (FR-059).
