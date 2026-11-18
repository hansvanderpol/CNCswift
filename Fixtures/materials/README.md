# Material Fixtures

This directory holds the material-library data used by tests, validation scenarios, and the
sign-off record for the shipped cutting bands.

## Status: PROVISIONAL

The four preset bands below are **provisional engineering guidance** for a 500 W-class spindle.
They are not certified cutting data and MUST NOT be presented as such until a cutting-experience
review is signed off in this file (research D11, task T111).

- Per-job confirmation of the effective feed and spindle stays mandatory whether or not this
  status changes (FR-079).
- Generation is not blocked while the review is pending; the block belongs to the per-job
  confirmation, not to the fixture status (plan task-shaping note 13).
- A record's band may sit outside the machine's limits and remains a valid record; it becomes an
  unusable job at resolution time (FR-080).

## Shipped preset bands

Exactly four presets ship, read-only, and are merged into the material library at load so a stale
stored copy can never shadow a preset revision (FR-077).

| Name | Feed band (mm/min) | Spindle band (RPM) |
|---|---|---|
| Softwood (pine/basswood) | 600-800 | 7000-8000 |
| Hardwood (oak/maple) | 400-600 | 7000-8000 |
| MDF | 500-700 | 7000-8000 |
| Plywood | 500-700 | 7000-8000 |

`presets.json` is the machine-readable copy of this table. It asserts the preset count, the
preserved names, the ordered positive bounds, and the provisional-status marker. Tests decode it
and compare it with the shipped `Presets.all` table, so a change to either side fails the build
until the other side is updated deliberately.

No metal, glass, stone, or non-wood composite-fibre presets ship. A user may define a material for
anything, and the app makes no safety claim about it.

## Cutting-experience sign-off (task T111)

Fill in every field below to move the bands out of provisional status. An unsigned record keeps
both `presets.json` and this file marked provisional.

| Field | Value |
|---|---|
| Reviewed by | _unsigned_ |
| Review date | _unsigned_ |
| Machine and spindle | _unsigned_ |
| Materials actually cut | _unsigned_ |
| Bands confirmed as shipped | _unsigned_ |
| Bands amended (with replacement values) | _unsigned_ |
| Outcome | **provisional** |

## Amendment rule

Changing a shipped band, adding a fifth preset, or removing one changes what the app recommends
for every job that selects it. Update `Fixtures/materials/presets.json`, `Fixtures/materials/README.md`,
and the preset table in `specs/001-stl-to-gcode/data-model.md` together; the fixture test fails
until they agree.
