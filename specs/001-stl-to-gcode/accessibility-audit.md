# Accessibility support record — 001-stl-to-gcode

**Feature**: `001-stl-to-gcode` | **Updated**: 2026-11-20

This record describes the implementation for FR-070/FR-071 and the evidence still owed for SC-009.
It is a record only; the executable gates remain `Scripts/ci.sh` and the per-package test suites.

## Implemented (T104, T105)

### Labels, roles, values, and reading order (FR-070)
Every custom control in `Packages/MainScreenUI/Sources/` and
`Packages/CutterLibraryModalUI/Sources/` now declares an explicit `accessibilityLabel`, a value
where state is carried, a hint when the action needs explanation, and a priority from a shared
`AccessibilityPriority` enum. Buttons keep their button trait; the 3D preview is exposed as an image
with a spoken camera state; combined elements (effective values, suggested job values, cutter rows,
keyboard shortcuts) suppress their children and announce one composed string.

Announcement wording lives in pure `AccessibilityText` enums so it is unit-tested:
`Packages/MainScreenUI/Tests/AccessibilityTests.swift` (3 tests) and
`Packages/CutterLibraryModalUI/Tests/AccessibilityTests.swift` (2 tests).

### System settings (FR-071)
`App/Sources/CNCswiftApp/Accessibility.swift` applies app-wide behaviour:
- **Reduce Motion** — a `nil` transaction animation removes implicit animation across the subtree.
- **Increase Contrast / Differentiate Without Color** — selection uses a visible outline and
  validation errors become bold and underlined instead of relying on tint alone.
- **VoiceOver** — generation-state changes post `AccessibilityNotification.Announcement`.
- **Full Keyboard Access** — the effective system setting is logged, and an Accessibility menu
  (`⌘?`) opens a keyboard reference listing the shortcuts for both primary workflows. The menus
  added in T106 (⌘G generate, ⌘S write, ⌘. cancel, ⇧⌘L cutter library) call the same model methods
  as the on-screen controls, so they cannot bypass blockers or the commit gate.

Effective settings are logged under the `ui` diagnostic category (FR-067/FR-068).

## Verification completed
- `Scripts/ci.sh`: exit 0 — format lint, offline audit, build, all 16 package suites green.
- MainScreenUI 10/10 and CutterLibraryModalUI 13/13, including the 5 new announcement tests.
- Freshly assembled bundle launched via `open`; no crash report after the build, zero outbound
  connections sampled.

## Remaining human verification (SC-009, T113/T114)
The following cannot be driven from a non-interactive shell and must be observed on the desktop.
Record a result in the last column; T113 stays open until every row is filled in. Re-confirmed
2026-11-20.

| # | Desktop step | Expected | Result (fill on desktop) |
|---|--------------|----------|--------------------------|
| 1 | With VoiceOver on, Tab through load STL → confirm units → confirm feed/spindle → confirm job values → acknowledge findings → write file. | Every control reachable, meaningful label/value announced, no pointing device. | pending |
| 2 | Repeat for the cutter-library workflow: open with ⇧⌘L, add a valid cutter, edit it, save, close. | Same reachability and announcements as row 1. | pending |
| 3 | Repeat rows 1–2 with Full Keyboard Access on and off. | Focus indicators remain visible; all shortcuts work in both modes. | pending |
| 4 | Repeat rows 1–2 with Increase Contrast on. | Validation errors remain distinguishable without tint alone. | pending |
| 5 | Repeat rows 1–2 with Reduce Motion on. | No animation plays; implicit transactions are removed. | pending |

Record the timed, keyboard-only result in `validation-evidence.md` (T113) when performed.
