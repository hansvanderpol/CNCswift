# Feature Specification: STL to Machine-Ready G-code

**Feature Branch**: `001-stl-to-gcode`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description: "Full vertical slice of CNCswift: take an STL model, a cutter from a maintained cutter library, and a carving material blank, and produce a validated GRBL 1.1 `.nc` program for the TwoTrees TTC450 PRO, previewed as a 3D material-removal simulation before it is written."

## Clarifications

### Session 2026-11-17

- Q: Should the cutting feed rate and spindle speed depend on the material being carved, or stay fixed per cutter? → A: Material sets a recommended feed and spindle band; the effective value is chosen inside the intersection of that band and the profile limits, prefilled from the cutter's record, confirmed per job, and recorded in the header with the material.
- Q: How should the 800 mm/min rapid-travel ceiling actually be enforced, given that GRBL's G0 move ignores any feed word? → A: Treat the rapid rate as machine setup through the controller's rapid-rate settings, keep every rapid above the stock at clearance height, and emit no feed word on a rapid.
- Q: Which materials should ship as built-in presets in the first version? → A: Wood and wood composites only: softwood (pine/basswood), hardwood (oak/maple), MDF, and plywood. MDF and plywood are the composites in scope.
- Q: What counts as a model feature "smaller than the cutter"? → A: A concave feature whose smallest inscribed radius is below the cutter's effective radius at the configured finishing stepover; the report gives both radii in millimetres and blocks generation.
- Q: What is the "reference model set" used by SC-003 and SC-012? → A: A fixed, versioned set of five STL fixtures committed under `Fixtures/stl/` and enumerated in `Fixtures/README.md`: an ASCII relief, a binary relief, a 200,000-triangle relief, a deep cavity, and a fine-detail relief. SC-012's 95% threshold is measured over this set; adding or removing a model requires an amendment.
- Q: When is the `.nc` file actually written relative to the 3D preview? → A: Generation builds and validates the program and renders the preview; the file is written only on a separate, explicit commit after the user has seen the preview and acknowledged any findings. No file is written by generation alone.
- Q: Should the US1 narrative and acceptance scenario say the app "produces one `.nc` file" or "writes exactly one `.nc` file"? → A: Use "writes exactly one `.nc` file" in both places for consistency.

### Session 2026-11-18

- Q: How should the 80 mm Z limit of the 460 x 460 x 80 mm envelope be measured relative to the work origin at the stock's top surface? → A: The 80 mm is the maximum stock thickness below the top surface (Z from 0 down to -80 mm); the mandatory clearance-height rapids above Z0 are exempt from this downward envelope limit.
- Q: After confirming the cutting settings and running generation, is the `.nc` file written at the end of generation or only after a separate explicit commit following the 3D preview? → A: Generation writes no file; the single `.nc` file is written only on an explicit commit after the user has seen the preview and acknowledged any findings.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate a validated G-code file from an STL (Priority: P1)

A maker opens the app, selects an STL model, chooses a cutter from the cutter library, picks the material being carved and enters the dimensions of the blank clamped to the bed, confirms the units and orientation of the model and the effective feed rate and spindle speed, and generates G-code. Generation builds, validates, and previews the program without writing any file; only after the user has seen the preview and explicitly commits does the app write exactly one `.nc` file that starts with the fixed start block, cuts the model in two stages (roughing to remove the bulk, then a raster finishing pass that follows the surface), and ends with the fixed stop block. The app refuses with a message that says exactly what is wrong when the job cannot be validated or committed.

**Why this priority**: This is the product. Everything else in the app exists to make this one file trustworthy. Without it there is no application, only a library and a viewer.

**Independent Test**: With a cutter record already present in the library, load a known reference STL, select a material, enter a stock blank, confirm units, orientation, and the effective feed and spindle, generate and confirm no file is written, review the preview, commit explicitly, then inspect the resulting `.nc` file: the first five lines are the start block in order, the last five are the stop block in order, no feed word exceeds the machine ceiling, no rapid carries a feed word, every coordinate lies inside the 460 x 460 x 80 mm envelope, and the file ends with `M30`.

**Acceptance Scenarios**:

1. **Given** a valid STL, a stored cutter, a selected material, and a stock blank inside the envelope, **When** the user confirms the effective feed and spindle and generates G-code, **Then** no file is written and a validated program and preview are ready. **Given** that ready state, **When** the user reviews the preview and explicitly commits, **Then** the app writes exactly one `.nc` file whose opening lines are `G21`, `G90`, `G94`, `G00 Z10.0`, `M3 S8000` in that order for a confirmed effective spindle of 8,000 RPM, before any cutting move.
2. **Given** a generated program, **When** the user inspects its final five lines, **Then** they are `G90`, `G00 Z15.0`, `M5`, `G00 X0 Y0`, `M30` in that order, and `M30` is the last line of the file.
3. **Given** a material whose spindle band and a cutter whose recorded speed both admit 6,000 RPM, **When** the user confirms 6,000 RPM and generates, **Then** the start block carries `M3 S6000`, the header records the material and the confirmed value, and no value outside 5,000-8,000 RPM appears as an `S` word.
4. **Given** a cutter whose recorded spindle speed is 4,500 RPM, **When** the user tries to save that cutter, **Then** the app rejects it with a message naming the permitted 5,000-8,000 RPM range, and no G-code can be generated from it.
5. **Given** a stock blank of 470 mm in X, **When** the user tries to generate, **Then** the app refuses with a message naming the 460 mm limit, and no file is written.
6. **Given** a model that extends beyond the stock blank, **When** the user tries to generate, **Then** the app refuses and offers an explicit uniform scale or a larger blank, and does not scale the model on its own.
7. **Given** the same model, cutter, material, stock, and confirmed job settings, **When** the user generates twice, **Then** the two files are byte-identical apart from the documented header fields.
8. **Given** generation is in progress, **When** the user cancels, **Then** no file is left on disk and the outcome is reported as cancelled, not as failed.
9. **Given** a material with a feed band of 300-600 mm/min and a cutter recorded at 750 mm/min, **When** the job settings open, **Then** the feed prefills at the band's upper bound of 600 mm/min, generation stays blocked until the user confirms it, and the header records the material, its band, and the confirmed value.
10. **Given** a material whose feed band starts at 1,200 mm/min, **When** the user selects it, **Then** the app refuses with a message naming the material and the 800 mm/min ceiling, and no value is trimmed into range.

---

### User Story 2 - Maintain the cutter library in a modal (Priority: P2)

A maker opens the cutter library from the main screen, adds a new cutter, picks its type (flat, ball nose, or V-bit), and enters its dimensions, flute count, and cutting values. The app rejects physically impossible records immediately and keeps the library on disk between launches.

**Why this priority**: The cutter record supplies the geometry that shapes the toolpath and the starting values for feed and spindle, so a wrong library silently produces a file that cuts with the wrong shape or the wrong load — the most expensive failure the app can have.

**Independent Test**: From a main screen with no library open, open the modal, create one cutter of each type with valid values, relaunch the app, and confirm all three records are present with identical values and valid identifiers.

**Acceptance Scenarios**:

1. **Given** an empty library, **When** the user creates a flat cutter with a cutting diameter, shank diameter, cutting length, flute count, feed rate, and spindle speed, **Then** the cutter is stored and selectable on the main screen without restarting the app.
2. **Given** the user selects the V-bit type, **When** the attribute form appears, **Then** it asks for an included angle and a tip diameter and does not accept a plain cutting diameter in their place.
3. **Given** a ball-nose cutter, **When** the user enters a negative ball diameter, **Then** the record is rejected at entry with a message and is not stored.
4. **Given** a V-bit with an included angle that cannot form a cone or a tip wider than its shank, **When** the user saves, **Then** the record is rejected at entry.
5. **Given** a stored library, **When** the app is relaunched, **Then** every cutter is present with the same identifier and values.
6. **Given** a library file written by an older schema version, **When** the app starts, **Then** the records are migrated forward with no loss and the previous file is preserved.
7. **Given** a library file written by a newer schema version than the app supports, **When** the app starts, **Then** the app refuses to modify it, reports the situation, and leaves the file intact.

---

### User Story 3 - Preview the carve in 3D before writing the file (Priority: P3)

Before committing a job, the maker looks at the simulation panel and sees the material blank as it will be left after the program runs: the roughing cavity and the finished surface. Violations such as a move outside the bed or an over-limit feed are called out before anything is written to disk.

**Why this priority**: A file that is syntactically valid can still ruin a blank or break a cutter. Seeing the removed material is the last cheap chance to catch a wrong cutter, wrong units, or a mirrored model.

**Independent Test**: Load a reference STL, generate the program, and confirm the simulation shows the stock with material removed following the model's surface, shows rapids as non-cutting, and lists any limit violations without writing a file.

**Acceptance Scenarios**:

1. **Given** a validated program, **When** the simulation panel renders it, **Then** the display shows the stock blank with removed material following the model's shape, viewed in 3D.
2. **Given** the same program, **When** the user inspects the preview, **Then** rapid repositioning moves are visibly distinguished from cutting moves and remove no material.
3. **Given** a program containing a move outside the envelope, **When** the simulation renders, **Then** the offending move is highlighted and named before the file is written.
4. **Given** a model with at least 50,000 triangles, **When** simulation runs, **Then** progress is reported and the operation can be cancelled, and a cancelled simulation is reported as cancelled rather than failed.
5. **Given** a model whose units were mis-confirmed, **When** the preview renders, **Then** the mismatch is visible as a carve that does not match the intended shape, allowing the user to stop before writing.

---

### Edge Cases

- **STL with no unit metadata**: every STL lacks units, so units and orientation are always confirmed explicitly; a model is never assumed to be in millimetres.
- **Corrupt or truncated STL**: binary file cut short, ASCII file with malformed facets, or an unsupported header. Rejected with a message naming the file and the defect; never partially decoded.
- **Empty mesh**: zero triangles, or all triangles degenerate. Rejected as having nothing to carve.
- **Non-manifold mesh**: open edges or non-manifold junctions. Rejected; no silent repair, hole-filling, or voxelisation.
- **Model entirely above the stock top or entirely below the stock bottom**: nothing would be removed. Rejected with a message explaining the Z relationship.
- **Model narrower than the cutter**: the cutter cannot enter the detail. Reported before generation with the smallest tool-relative feature that cannot be cut.
- **Cutter cutting length shorter than the stock depth**: rejected at generation with the required length named.
- **Stepover at or above the cutting diameter**: rejected, because the pass would leave uncut ridges.
- **Maximum depth per pass exceeding the cutter's cutting length**: rejected.
- **Stock dimension of zero or a negative value**: rejected at entry.
- **Empty library**: generation is blocked with a message directing the user to create a cutter in the library, rather than substituting a default tool.
- **Cutter deleted while selected on the main screen**: the selection is cleared and generation is blocked until a stored cutter is chosen again.
- **Library file missing**: the app starts with an empty library and says so; it does not recreate records or restore from guesswork.
- **Library file corrupt**: reported with the file location and a preserved backup; never silently discarded.
- **Disk full or write permission denied**: the write fails with an actionable message and no partial `.nc` file remains.
- **Generation cancelled mid-job**: no file is written.
- **App quit during a long generation**: no partial file is left behind.
- **Spindle speed or feed exactly at a limit**: 5,000 RPM, 8,000 RPM, and 800 mm/min are all accepted; only values beyond the limits are rejected.
- **Material band overlapping a profile limit at a single value**: for example a feed band of 600-800 mm/min against the 800 mm/min ceiling. That boundary remains available, is prefilled, and still requires confirmation.
- **Material band with no overlap with the profile limits**: for example a feed band starting at 1,200 mm/min. Rejected before generation, naming the material and the limit it cannot satisfy; the band is never trimmed into range.
- **Cutter value outside the material band**: the nearest bound of the intersection is prefilled instead, and generation stays blocked until the user confirms it.
- **Unconfirmed rapid-rate setup**: generation is blocked with a message naming the controller settings that must be applied, because no line in the program can enforce the rapid ceiling.
- **Move that lands exactly on the envelope boundary**: accepted at exactly 460 x 460 x 80 mm; anything beyond is rejected.

## Requirements *(mandatory)*

### Functional Requirements

#### Input and geometry

- **FR-001**: System MUST accept stereolithography (STL) files, both ASCII and binary, selected from the local file system.
- **FR-002**: System MUST reject unsupported, corrupt, or truncated files with an actionable message naming the file and the defect.
- **FR-003**: System MUST reject empty meshes (no triangles, or all triangles degenerate) and non-manifold meshes.
- **FR-004**: System MUST NOT repair, fill, voxelise, or otherwise modify input geometry silently; silent repair is prohibited.
- **FR-005**: System MUST require explicit user confirmation of model units and orientation before any toolpath is computed, and MUST NOT assume millimetres.
- **FR-006**: System MUST NOT apply an unconfirmed scale factor; a scale change requires explicit user action and MUST be reported in the generated file header.
- **FR-007**: System MUST keep all geometry in millimetres, in a declared coordinate system with a declared origin, and record that origin in the generated file header.
- **FR-008**: System MUST treat the carving material's stock as a rectangular blank whose X, Y, and Z dimensions the user enters in millimetres.
- **FR-009**: System MUST place the work origin at the stock blank's front-left top corner, with X0 Y0 at that corner and Z0 at the top surface, and MUST state this convention on the main screen.
- **FR-010**: System MUST reject a stock blank outside 460 x 460 x 80 mm (X x Y x Z) or with a non-positive dimension, naming the offending dimension and the limit.
- **FR-011**: System MUST reject a model that does not lie within the stock blank, rather than clipping it, moving the origin, or scaling it without consent.
- **FR-012**: System MUST apply an explicit, documented, test-covered transform from model space to machine space.

#### Machine profile and output

- **FR-013**: System MUST describe the target machine in exactly one versioned machine profile holding its dialect, work envelope, feed limit, the rapid rate its controller must be set to, spindle range, tool activation, supported commands, start block, stop block, and output file extension.
- **FR-014**: System MUST record the machine profile version in every generated file header.
- **FR-015**: Toolpath and formatting stages MUST NOT hardcode dialect tokens, limits, or block contents; every dialect token and limit MUST come from the machine profile.
- **FR-016**: A different machine MUST be a new profile, never a new code path.
- **FR-017**: System MUST emit only commands implemented by the profile's dialect (GRBL 1.1), and MUST NOT emit `G43` tool-length offsets, `M6` tool changes, vendor macros, custom M-codes, or controller extensions.
- **FR-018**: System MUST write exactly one plain-text output file per generation, with the `.nc` extension; `.gcode`, `.tap`, and `.ngc` MUST NOT be produced.
- **FR-019**: System MUST open every generated program with the profile's start block, in exactly this order and with no line omitted, before any cutting move: `G21`, `G90`, `G94`, `G00 Z10.0`, and `M3` carrying the `S` word.
- **FR-020**: System MUST close every generated program with the profile's stop block, in exactly this order and with no line omitted, after the last cutting move: `G90`, `G00 Z15.0`, `M5`, `G00 X0 Y0`, `M30`.
- **FR-021**: System MUST make `M30` the final line of every generated file, and MUST stop the spindle with `M5` before returning to the origin.
- **FR-022**: System MUST carry the spindle speed as an `S` word in RPM; the value MUST be the effective spindle speed resolved under FR-079, and the system MUST reject a speed outside 5,000-8,000 RPM inclusive rather than clamping it.
- **FR-023**: System MUST reject any cutting feed above 800 mm/min rather than clamping it.
- **FR-024**: System MUST emit every rapid traverse as a `G0` move carrying no feed word, and MUST NOT claim in the file to control the rapid rate, because the profile's dialect ignores any feed word on a rapid; the 800 mm/min rapid ceiling MUST instead be met by the controller's rapid-rate settings, documented as required machine setup and confirmed on the main screen before generation, working together with the clearance-height rule in FR-039.
- **FR-025**: System MUST keep every emitted move inside the profile's 460 x 460 x 80 mm envelope, treating the boundary itself as inside, and MUST fail loudly for geometry the profile cannot represent rather than approximating it. The 80 mm is the stock blank's Z depth measured downward from the work origin at the top surface (Z from 0 to -80 mm inclusive); the mandated clearance-height rapids at Z10.0 and Z15.0 lie above the stock and are exempt from this downward envelope limit.
- **FR-026**: System MUST validate a program before writing it: it MUST parse as GRBL 1.1, stay inside the envelope and declared limits, and carry the start and stop blocks verbatim in their declared order.
- **FR-027**: System MUST write the file atomically, so that no partially written or intermediate file is ever visible as the result.
- **FR-028**: System MUST produce deterministic output: the same model, confirmed settings, and profile version MUST yield byte-identical files apart from the documented header fields.
- **FR-029**: System MUST record in the file header the cutter identifier, the cutter type, the attribute values actually used, the machine profile version, the job settings, the declared units and origin, any confirmed scale, and the material fields defined by FR-081.
- **FR-030**: System MUST NOT stream to, drive, or control machine hardware; writing the file is the only output.
- **FR-031**: System MUST NOT emit laser-specific output, including power modulation, laser-mode enable settings, and dynamic-power moves.
- **FR-082**: System MUST emit every G-code line, including header and comment lines, with at most 80 characters, and MUST reject any program containing a longer line rather than emitting it.

#### Toolpath generation

- **FR-032**: System MUST generate a program in two stages: a roughing stage that removes the bulk of the material in layers, and a raster finishing stage that follows the model surface.
- **FR-033**: System MUST limit each roughing layer and each finishing pass to the user's maximum depth per pass, which MUST NOT exceed the selected cutter's cutting length.
- **FR-034**: System MUST leave the user's finishing allowance of material after roughing, and MUST reject an allowance that is negative or that consumes the whole stock depth.
- **FR-035**: System MUST apply the user's stepover to the finishing pass, and MUST reject a stepover that is not greater than zero or that is at or above the cutter's cutting diameter.
- **FR-036**: System MUST derive every toolpath shape from the selected cutter's recorded geometry, and MUST recompute toolpaths when that geometry changes rather than reusing a stale result.
- **FR-037**: System MUST prefill job-strategy settings (stepover, maximum depth per pass, and finishing allowance) derived from the selected cutter and stock, and MUST require explicit confirmation before generation; an unconfirmed value MUST NOT be applied. This job-strategy prefill is distinct from the cutting-value prefill in FR-079.
- **FR-038**: System MUST restrict carving to the model's footprint plus at most the cutter's radius of margin, and MUST NOT sweep the whole blank.
- **FR-039**: System MUST perform rapid repositioning at the profile's clearance height and MUST NOT rapid through material.
- **FR-040**: System MUST require explicit per-job confirmation of both the cutting feed rate and spindle speed resolved under FR-079 before generation, and MUST NOT substitute an unconfirmed value at generation time.
- **FR-041**: System MUST report, before generation, any model feature smaller than the selected cutter can carve. A feature is "too small" when its smallest concave radius is below the cutter's effective radius at the configured finishing stepover. The report MUST state both radii in millimetres and MUST block generation until the model, cutter, or stepover changes.

#### Cutter library

- **FR-042**: System MUST keep one authoritative library of mill cutters (end mills) with stable identifiers.
- **FR-043**: G-code creation MUST consume cutters from the library read-only.
- **FR-044**: System MUST model cutter type as a closed enumeration of flat, ball nose, and V-bit, and MUST NOT store a cutter as an untyped diameter.
- **FR-045**: System MUST require shank diameter, cutting length, flute count, feed rate, and spindle speed for every cutter, plus the dimensions defining its type: cutting diameter for flat, ball diameter for ball nose, and included angle plus tip diameter for V-bit.
- **FR-046**: System MUST reject an attribute belonging to another type used as a substitute, and MUST NOT share a bare diameter field across types where its meaning differs.
- **FR-047**: System MUST express every dimension in millimetres with exactly one defined meaning per type.
- **FR-048**: System MUST validate cutters at entry and reject them there rather than at generation time: non-positive sizes, an invalid flute count, an included angle that cannot form a cone, a tip wider than the shank, a feed above 800 mm/min, and a spindle speed outside 5,000-8,000 RPM inclusive.
- **FR-049**: System MUST block generation with an actionable message when a required cutter attribute is absent, and MUST NOT substitute a default.
- **FR-050**: System MUST reference cutters from saved work by identifier, never by copied attribute values.
- **FR-051**: System MUST store the library in the user's Application Support directory, write it atomically, and stamp it with a schema version.
- **FR-052**: System MUST migrate the library forward between schema versions using tested fixtures from the prior version, and MUST NOT perform a destructive or lossy migration.
- **FR-053**: System MUST refuse to modify a library written by a schema version newer than the app supports, report the situation, and leave the file intact.
- **FR-054**: System MUST report a missing or corrupt library file with its location, preserve a backup, and MUST NOT silently discard or rebuild records.

#### Main screen and library modal

- **FR-055**: System MUST present exactly one user-facing mode, G-code creation, on a main screen carrying exactly three panels: cutter selection, carving material (material choice, stock dimensions, and the effective feed rate and spindle speed), and G-code simulation.
- **FR-056**: System MUST present cutter-library maintenance in a modal view opened from the main screen, and MUST NOT embed that maintenance in the main screen.
- **FR-057**: System MUST implement the main screen and the library modal as separate modules, each with its own view model and entry point, each usable without the other running.
- **FR-058**: System MUST NOT share mutable in-memory state between the main screen and the modal; the persisted cutter library is the only shared contract.
- **FR-059**: System MUST limit imports between the two presentations to the cutter library, shared geometry, and shared persistence.
- **FR-060**: System MUST clear the main screen's cutter selection when the selected cutter is deleted, and block generation until a stored cutter is chosen.

#### Simulation

- **FR-061**: System MUST render the validated program as a 3D material-removal simulation of the stock blank before the file is written.
- **FR-062**: System MUST show the roughing cavity and the finished surface as they will remain after the program completes.
- **FR-063**: System MUST distinguish rapid moves from cutting moves in the preview and MUST NOT remove material for rapid moves.
- **FR-064**: System MUST highlight and name any envelope or limit violation in the preview before the file is written.
- **FR-065**: System MUST simulate the same validated program that is written, and MUST NOT derive the preview from a separate, divergent path.
- **FR-066**: System MUST report progress and allow cancellation during simulation for any model with at least 50,000 triangles, and MUST report cancellation as distinct from failure.

#### Diagnostics, accessibility, and privacy

- **FR-067**: System MUST use typed errors, show the user an actionable message, and record the cause with a stable correlation identifier in a structured log.
- **FR-068**: System MUST log through per-module structured logging with stable categories, and MUST NOT use unstructured console printing in shipping code.
- **FR-069**: System MUST report progress and allow cancellation for decoding, generation, and simulation whenever the model has at least 50,000 triangles, and MUST distinguish cancellation from failure in both the log and the interface.
- **FR-070**: System MUST make every primary workflow operable by keyboard alone, and MUST expose accessibility labels, roles, and values on custom controls.
- **FR-071**: System MUST honor VoiceOver, Increase Contrast, Reduce Motion, and full keyboard access.
- **FR-072**: System MUST follow macOS conventions for the menu bar, standard shortcuts, window restoration, and settings.
- **FR-073**: System MUST run sandboxed with only the entitlements it uses, and MUST declare each file and hardware entitlement it needs.
- **FR-074**: System MUST keep all user data on the local machine, MUST NOT transmit models, cutters, or generated files over a network, and MUST NOT collect telemetry or analytics.
- **FR-075**: System MUST identify the app as `com.hansvanderpol.CNCswift` and MUST NOT change that identifier without an explicit amendment.
- **FR-076**: System MUST be prepared for local build and run only, with no App Store submission, Developer ID signing, or notarization in scope.

#### Carving material

- **FR-077**: System MUST model the carving material as an entity carrying a name, a recommended cutting-feed band in mm/min, and a recommended spindle-speed band in RPM, kept separate from the stock blank's dimensions; the app MUST ship exactly four built-in presets — softwood (pine/basswood), hardwood (oak/maple), MDF, and plywood — and MUST allow the user to define additional materials that persist across launches.
- **FR-078**: System MUST validate a material at entry: every band bound MUST be greater than zero and a band's lower bound MUST NOT exceed its upper bound; a malformed band MUST be rejected with an actionable message and MUST NOT be corrected, widened, or clamped.
- **FR-079**: System MUST resolve each effective cutting value (feed rate and spindle speed) as the intersection of the material's recommended band and the machine profile's limits, MUST let the user confirm any value inside that intersection for the job, MUST prefill the selected cutter's recorded value when it lies inside the intersection and otherwise the nearest bound of the intersection, and MUST NOT apply a value outside the intersection. This cutting-value prefill is distinct from the job-strategy prefill in FR-037.
- **FR-080**: System MUST reject, before generation, a material whose feed or spindle band has no value in common with the machine profile's limits, naming the material, the band, and the ceiling or floor it cannot satisfy, and MUST NOT clamp the band into range.
- **FR-081**: System MUST record in the file header the material name, its recommended feed and spindle bands, and the effective feed rate and spindle speed actually used, alongside the selected cutter's recorded values. This is the single canonical list of material header fields referenced by FR-029.

### Key Entities *(include if feature involves data)*

- **STL Model**: the source file, its declared units and orientation as confirmed by the user, any confirmed scale, its triangle set, and its bounds in millimetres.
- **Stock Blank**: the rectangular block of carving material the user clamps to the bed, defined by X, Y, and Z dimensions in millimetres and the work origin convention.
- **Carving Material**: the named material being cut, carrying a recommended cutting-feed band in mm/min and a recommended spindle-speed band in RPM; distinct from the stock blank, which supplies only dimensions.
- **Machine Profile**: the single versioned description of the target machine: dialect, work envelope, feed ceiling, the rapid ceiling the controller must be set to, spindle range, tool activation, supported commands, fixed start and stop blocks, and output extension.
- **Cutter**: one mill cutter record with a stable identifier, a closed type, the dimensions its type requires, shank diameter, cutting length, flute count, feed rate, and spindle speed.
- **Cutter Library**: the versioned, atomically written collection of cutters with its schema version, the only shared contract between the main screen and the modal.
- **Job Settings**: the confirmed choices that bind a model, stock, material, and cutter together: stepover, maximum depth per pass, finishing allowance, the confirmed effective feed rate and spindle speed, and the confirmed units and orientation.
- **Toolpath**: the ordered roughing layers and raster finishing passes derived from the model, cutter geometry, stock, and job settings, split into rapid and cutting moves.
- **G-code Program**: the validated ordered move list with the fixed start and stop blocks and the documented header.
- **Simulation Result**: the material removed from the stock blank by the program, with rapids excluded, plus any envelope or limit violations found.
- **Generation Record**: the header content that makes a file reproducible: cutter identifier and type, the cutter's attribute values, the material name and its recommended bands, the effective feed rate and spindle speed used, profile version, job settings, units, origin, and any confirmed scale.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with an existing cutter record can go from choosing an STL to a written `.nc` file for a 200,000-triangle model in under 5 minutes on the reference machine (macOS 27.2.1, arm64 Apple silicon), with no external documentation.
- **SC-002**: 100% of generated files pass an independent check of GRBL 1.1 syntax, the 460 x 460 x 80 mm envelope, the 800 mm/min feed ceiling, the recorded controller rapid-rate setting, and the 5,000-8,000 RPM spindle range on the first attempt.
- **SC-003**: Zero generated files contain a reordered, truncated, or missing start or stop block, or a final line other than `M30`, across the full reference model set.
- **SC-004**: 100% of invalid inputs — corrupt, truncated, empty, non-manifold, oversize, under-specified cutter, or out-of-range value — are rejected with a message naming the problem and the fix, and zero are silently repaired, clamped, scaled, or defaulted.
- **SC-005**: Generating the same job twice produces byte-identical files apart from documented header fields in 100% of runs.
- **SC-006**: A user reaches a first valid `.nc` file from an empty cutter library in under 10 minutes, including creating the cutter, on the first attempt without help.
- **SC-007**: A cutter created or edited in the modal is reflected in the next generated file's header without relaunching the app, in 100% of attempts.
- **SC-008**: 100% of library records survive an upgrade across two consecutive schema versions in fixture tests, and zero records are lost or silently altered.
- **SC-009**: Both primary workflows — generating G-code and maintaining cutters — are completed with the keyboard alone by a tester using no pointing device.
- **SC-010**: A full session, from launch through generation, opens zero outbound network connections as observed by a network monitor.
- **SC-011**: 100% of cancelled or failed generations leave no `.nc` file and no partial artifact on disk.
- **SC-012**: For 95% of reference models, the 3D preview renders within 5 seconds of the program being validated, and every limit violation present is highlighted.
- **SC-013**: In 100% of generated files, the effective feed rate and spindle speed lie inside the intersection of the material's recommended band and the profile's limits, the header records the material, its bands, and both effective values, and zero files are written from an empty intersection.

## Assumptions

- The STL format carries no unit metadata, so the user confirms units and orientation for every model rather than inheriting a remembered choice.
- The work origin is the stock blank's front-left top corner, with Z0 at the top surface, which is consistent with the start block's 10 mm clearance and the stop block's 15 mm lift.
- One cutter is used per program; GRBL 1.1 has no tool-change command, so a job that needs two cutters is done as two programs.
- "Carving material" has two parts: a named material carrying recommended cutting-feed and spindle-speed bands, and the stock blank's dimensions. A machine ceiling of 800 mm/min is lower than what many materials and cutters would normally allow, so the profile's limits, not the material band alone, bound the effective value.
- Feed rate and spindle speed are chosen per job inside the intersection of the material's band and the profile's limits, prefilled from the cutter's record, because the same cutter is run differently in softwood and in MDF.
- The four built-in preset bands are starting recommendations for a machine of this class, not certified cutting data; the user confirms the actual value for each job rather than treating the preset as authority.
- Materials outside the four presets are the user's own definitions; the first version ships no metal, glass, stone, or non-wood composite-fibre bands, and nothing in the app claims those materials are safe to cut. MDF and plywood are wood composites and are included in the four presets.
- The controller's rapid-rate settings are machine setup performed once by the operator, since GRBL's `G0` accepts no feed word; the app documents the required values and records the confirmation rather than pretending the program enforces them.
- Stepover, maximum depth per pass, and finishing allowance are job settings, not cutter attributes, because they describe the machining strategy rather than the tool.
- The reference machine is the TwoTrees TTC450 PRO, described by one machine profile; a second machine would be a new profile rather than new code.
- The cutter library starts empty on first run, and a cutter must exist before any file can be generated.
- The app is built and run locally on the developer's Mac; signing, notarisation, and distribution are out of scope.
- The reference environment is macOS 27.2.1 on arm64 Apple silicon, matching the verified toolchain recorded in `plan.md`.

## Out of Scope

- Raster image input; STL meshes are the only input family.
- Laser output, power modulation, and laser-mode controller settings.
- Streaming to, driving, or controlling the machine over a serial connection.
- Tool changes within a single program, and `G43` tool-length offsets.
- Cutter wear and life tracking, tool-change sheets, machine offsets, and job or machine management.
- Silent geometry repair, mesh healing, and automatic scaling.
- Alternative G-code dialects and additional machine profiles.
- App Store submission, Developer ID signing, notarisation, and any distribution channel.
- Telemetry, analytics, and any network transmission of user data.
