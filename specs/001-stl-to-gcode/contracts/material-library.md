# Contract: Material Library

**Producer**: `CNCMaterials` (entity, presets, validation, resolution) and `CNCMaterialsStore` (persistence) | **Consumers**: `CNCToolpath` (resolved values), `CNCGCode` (header fields), `MainScreenUI` (selection and confirmation).

Two libraries exist in the app. The cutter library describes the tool; the material library describes what the tool is cutting. They are separate documents with separate schemas, and neither is allowed to define values belonging to the other (FR-077).

## Built-in presets

Exactly four presets ship, read-only, merged into the library at load (FR-077):

| Name | Feed band (mm/min) | Spindle band (RPM) |
|---|---|---|
| Softwood (pine/basswood) | 600-800 | 7000-8000 |
| Hardwood (oak/maple) | 400-600 | 7000-8000 |
| MDF | 500-700 | 7000-8000 |
| Plywood | 500-700 | 7000-8000 |

The values are provisional engineering guidance for a 500 W-class spindle until cutting-experience sign-off is recorded in `Fixtures/materials/README.md` (research D11, task T111). They live in one preset table with a fixture that asserts the count, the names, the band order, and that every bound is positive; the fixture is marked provisional until sign-off. The spec deliberately does not contain these numbers; they are data, not requirements. Sign-off does not replace per-job confirmation.

No metal, glass, stone, or non-wood composite-fibre presets ship; MDF and plywood are the wood composites included in the four presets. A user may define a material for anything, and the app makes no safety claim about it.

## Material record

| Field | Type | Rule |
|---|---|---|
| `id` | stable identifier | Assigned once, never reused; presets use fixed IDs |
| `name` | string | Non-empty after trimming; unique across presets plus user materials |
| `feedBand` | closed range | Both bounds > 0, lower <= upper (FR-078) |
| `spindleBand` | closed range | Both bounds > 0, lower <= upper (FR-078) |
| `origin` | `builtIn` \| `user` | Built-ins are not editable in place; "editing" a preset creates a user copy with a new ID |
| `shippedVersion` | string, built-ins only | Preset revision marker |

Bands are never clamped at entry, and a band whose values exceed the machine's limits is still a valid record: it becomes an unusable job at resolution time (FR-080), not a rejected material. This distinction is deliberate — the material's recommendation is a physical fact, while the machine's ceiling is the app's constraint.

## Entry validation (FR-078)

Rejected at entry with a typed error naming the field and the bound:

| Rule | Condition |
|---|---|
| Positive bounds | Every one of the four bounds is greater than zero |
| Ordered band | `feedBand.lower <= feedBand.upper` and `spindleBand.lower <= spindleBand.upper` |
| Non-empty name | Not empty after trimming |
| Unique name | No collision with a preset or an existing user material |
| Identifier | Unique and immutable after assignment |

Rejected records are never persisted, never renamed silently, and never merged into an existing record.

## Resolution (FR-079, FR-080)

One function, one owner:

```text
resolve(material, cutter, profile):
  feedRange    = intersect(material.feedBand, [0, profile.maxFeedRate])
  spindleRange = intersect(material.spindleBand, [profile.spindleMin, profile.spindleMax])

  if feedRange is empty -> .noOverlap(.feed(material, band, profile.maxFeedRate))
  if spindleRange is empty -> .noOverlap(.spindle(material, band, profile.spindleRange))

  feedPrefill    = cutter.feedRate    if inside feedRange else nearestBound(feedRange)
  spindlePrefill = cutter.spindleSpeed if inside spindleRange else nearestBound(spindleRange)

  return .resolved(feed: feedPrefill, spindle: spindlePrefill,
                   source: prefillSource, confirmed: false)
```

Rules that follow from this contract:

1. The intersection is always with the profile's limits, never with another material's.
2. The cutter's recorded value is a prefill, not an authority. It is offered only when it lies inside the intersection (FR-079).
3. When the cutter value is outside, the nearest bound is prefilled and flagged as such, so the UI can explain why the value differs from the cutter record.
4. `confirmed` starts false for every job. An unconfirmed value blocks generation; nothing is applied silently (FR-037, FR-040).
5. A value the user confirms must already lie inside the intersection; the UI cannot construct an out-of-range `EffectiveCuttingValues`.
6. The intersection is computed per job, not cached across jobs, because changing the material, cutter, or profile can change it.
7. `.noOverlap` carries the material name, the offending band, and the specific ceiling or floor, so the message names what cannot be satisfied (FR-080).

## Storage

| Property | Value |
|---|---|
| Location | `Application Support/CNCswift/materials.json` inside the sandbox container |
| Format | UTF-8 JSON, two-space indent, stable key order, `\n` endings |
| Schema version | Integer `schemaVersion` at the document root |
| Write | Atomic replace through `CNCStorage`, previous file retained as backup |
| Load failure | Report path, preserve backup, never discard or rebuild user materials |
| Migration | Forward-only, fixture-tested per version step, no record loss |
| Newer schema | Refused, reported, file left byte-identical |

Document shape:

```json
{
  "schemaVersion": 1,
  "materials": [
    {
      "id": "6a1d2f70-3c4b-4e21-9f88-1b2c3d4e5f60",
      "name": "Reclaimed oak",
      "feedBand": { "lower": 350.0, "upper": 550.0 },
      "spindleBand": { "lower": 7000.0, "upper": 8000.0 },
      "origin": "user"
    }
  ]
}
```

Presets are not written to the document. They are code-shipped data merged at load, so a preset revision cannot be shadowed by a stale stored copy.

## Interaction contract

- The main screen's material panel lists presets first, then user materials, and shows the selected band in the panel (FR-055).
- Choosing a material recomputes the effective values and re-prefills them; it never silently keeps a value from the previous material.
- Changing the cutter or the material clears confirmation, because the confirmed value belonged to the previous combination.
- The panel shows the material's band, the profile limit that applied, and the resulting value, so the operator can see why a number changed.
- Creating or editing a user material validates at entry in the panel, not at generation time.
- Deleting the selected user material clears the selection, the same way a deleted cutter does (FR-060), and blocks generation until another material is chosen.

## Tests this contract requires

| Test | Proves |
|---|---|
| Preset fixture: exactly four, names and ordered bands, marked provisional until `Fixtures/materials/README.md` records sign-off | FR-077, research D11 |
| Malformed band rejected at entry, record not stored | FR-078 |
| Cutter inside intersection prefills with its own value | FR-079 |
| Cutter outside intersection prefills the nearest bound and flags the source | FR-079 |
| Confirmed value outside intersection is impossible to construct | FR-079 |
| Band starting above the feed ceiling returns `.noOverlap(.feed)` naming material, band, and 800 | FR-080 |
| Band ending below the spindle floor returns `.noOverlap(.spindle)` naming 5,000 | FR-080 |
| User material round-trips through storage with the same identifier | FR-077 persistence |
| Newer schema refused, file byte-identical | Cutter-library parity |
| Header contains material name, both bands, and both effective values | FR-081 |
