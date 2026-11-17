# Contract: G-code Output File

**Producer**: `CNCGCode` | **Consumer**: the TTC450 PRO controller, and `CNCValidation` as an independent reader.

This contract is the product. A file that violates it is a broken build, not a formatting nit (Principle VI).

## File-level rules

| Rule | Value | Reference |
|---|---|---|
| Encoding | UTF-8, ASCII-only content | FR-018 |
| Line ending | `\n` only | research D8 |
| Extension | `.nc`, exactly one file per generation | FR-018 |
| Maximum line length | 80 characters | research D8, GRBL `error:11` |
| Trailing newline | Required after `M30` | FR-021 |
| Determinism | Byte-identical for identical inputs; only the header timestamp may differ | FR-028 |
| Atomicity | Written to a temporary sibling then moved into place; no partial file is ever visible | FR-027 |

The 80-character limit is a derived constraint, not a spec sentence: GRBL's line buffer is `LINE_BUFFER_SIZE` bytes and an over-long line aborts mid-program. It is enforced by the formatter and re-checked by the validator. A future spec revision should give it a requirement number so it is traceable without reading research.

## Header

`;` comments, one fact per line, each line at most 80 characters. Field order is fixed. The only field permitted to vary between two runs of the same job is `generated`.

```gcode
; CNCswift 1.0
; profile: twotrees-ttc450-pro 1.0.0
; dialect: grbl1_1
; units: mm  origin: stock front-left top
; model: relief-demo.stl
; cutter: 8f3c1d2a-...
; cutter-name: 6mm flat
; cutter-type: flat
; cutting-diameter: 6.000
; shank-diameter: 6.000
; cutting-length: 20.000
; flutes: 2
; cutter-feed: 750.000
; cutter-spindle: 8000
; material: hardwood (oak/maple)
; material-feed-band: 400.000-600.000
; material-spindle-band: 7000-8000
; feed: 600.000
; spindle: 8000
; rapid-rate: controller 800 (see $110-$112)
; stock: 200.000 x 150.000 x 30.000
; stepover: 2.400
; max-depth: 2.000
; allowance: 0.500
; scale: 1.000
; generated: 2026-11-17T09:12:44Z
;
```

Rules:

- `cutter` is the stable identifier; the attribute values follow so the file is reproducible after the library changes (FR-029).
- `cutter-feed` and `cutter-spindle` are the cutter record's own values. `feed` and `spindle` are the effective values actually commanded. When they differ, the header shows both rather than hiding the substitution (FR-081).
- `material` is the material name; the two band lines give the band that constrained the choice (FR-081).
- `spindle` equals the value emitted in the start block's `S` word.
- `rapid-rate` states that the ceiling is a controller setting, so nobody reads the file and concludes the program enforces it (FR-024).
- `scale` records the multiplier actually applied after explicit confirmation (FR-006).
- Values are formatted with three decimals except integers (`flutes`, `spindle`, band ranges, `$` references) and the profile version.
- No header line may exceed 80 characters. A long material name is truncated with an ellipsis in the header only; the full name stays in the UI and the material library.

## Program body order

1. Header comments.
2. Start block, verbatim in profile order, before any cutting move:

   ```gcode
   G21
   G90
   G94
   G00 Z10.0
   M3 S8000
   ```

3. Roughing moves, deepest layers first.
4. Finishing raster moves.
5. Stop block, verbatim in profile order, after the last cutting move:

   ```gcode
   G90
   G00 Z15.0
   M5
   G00 X0 Y0
   M30
   ```

`M5` must stop the spindle before the origin return, and `M30` must be the last non-empty line (FR-021).

## Body formatting

- Absolute positioning assumed after `G90`; each cutting line carries `X`, `Y`, `Z` only where they change, `F` only when it changes.
- Modal `G1` is emitted once, then re-emitted after any `G0` run, so a reader never has to infer the mode across a rapid.
- **A rapid line never carries an `F` word.** GRBL ignores it on `G0`, and writing it would misrepresent the file (FR-024). The rapid rate is a controller setting recorded in the header.
- Rapid moves use `G0 Z{clearance}` before traversing in XY and before descending, so the cutter never rapids through material (FR-039).
- Numbers: exactly three decimals, invariant locale, no exponent, no thousands separator, no leading `+`. Negative zero is normalised to `0.000`.
- Comments inside the body are permitted only as section markers and still obey the 80-character limit.

## Example fragment

```gcode
G1 X10.000 Y10.000 Z-1.000 F600.000
G1 X12.400 Y10.000 Z-1.180
G1 X14.800 Y10.000 Z-1.420
G0 Z10.000
G0 X10.000 Y12.400
G1 Z-1.420 F600.000
```

Note the third-from-last line: a rapid with no feed word, followed by a cutting move that restores the modal feed explicitly.

## Validation obligations

`CNCValidation` must, independently of the emitter:

1. Parse every line against the GRBL 1.1 subset and reject unknown words.
2. Track modal state (units, distance, feed mode, motion, spindle) and reject a line whose meaning depends on an unsupported mode.
3. Reject any line longer than 80 characters.
4. Reject coordinates outside the envelope and cutting feeds above the ceiling.
5. Reject an `F` word on a rapid line, and any `S` word outside 5,000-8,000 RPM.
6. Confirm the start and stop blocks appear verbatim, in order, at the head and tail.
7. Confirm `M30` is the last line and `M5` precedes the origin return.
8. Reject a `$` setting command, a laser-mode token, or any word in `unsupportedCommands`.
9. Report findings with line numbers and a correlation identifier.

Any error-severity finding blocks the write (FR-026).

## Explicitly forbidden in output

- `G43`, `G43` tool-table offsets, `M6`, tool changes, vendor macros, custom M-codes, controller extensions (FR-017).
- Laser power modulation, laser-mode enable, dynamic-power moves (FR-031).
- `$` setting commands, including the `$110`-`$112` settings this app relies on (machine setup, never program content).
- `.gcode`, `.tap`, `.ngc` extensions (FR-018).
- Any line above 80 characters (research D8).
- Any cutting feed above 800 mm/min and any spindle speed outside 5,000-8,000 RPM, whether clamped or not (FR-022, FR-023).
- An `F` word on a rapid, or any claim in the file that the program controls the rapid rate (FR-024).
