# Reference Fixtures

This directory holds every fixed input used by builds, tests, and validation scenarios.

## Reference STL models (exactly five)

The following five models are the complete reference set for SC-003 and SC-012. Each is
versioned independently; the current version is recorded in the table.

| Version | File | Purpose |
|---|---|---|
| v1 | `stl/relief-demo-ascii.stl` | Small ASCII-encoded relief. Proves content-based ASCII detection and decode. |
| v1 | `stl/relief-demo-binary.stl` | The same relief encoded as binary STL. Proves that encoding detection is content-based, not extension-based. |
| v1 | `stl/relief-demo-200k.stl` | Dense binary relief of 200,000 triangles. Drives the decode/generation and preview performance criteria (SC-001, SC-012). |
| v1 | `stl/deep-cavity.stl` | Deep rectangular pocket. Exercises cavity-aware roughing and tool reach. |
| v1 | `stl/fine-detail.stl` | Fine, high-frequency surface detail. Exercises the minimum feature-size rule (FR-041). |

All five models are watertight, manifold, non-degenerate, and expressed in millimetres with a
front-left-top origin convention. They are read-only reference data; the decoder must never
repair, rescale, or fill them.

## Other fixture directories

- `gcode/` — reviewed golden `.nc` files, treated as production output.
- `library/` — cutter library documents, one per supported schema version.
- `materials/` — preset-band fixture and user-material documents.

## Amendment rule

Adding or removing a reference STL model changes the denominator of SC-003 and SC-012 and
therefore requires an amendment to `specs/001-stl-to-gcode/spec.md` and a regeneration of the
affected golden files. Do not silently add a sixth model to this table.
