## Summary

<!-- What changed and why? Link the feature and task IDs, e.g. specs/001-stl-to-gcode/tasks.md T111. -->

## Principles touched

<!-- State the CNCswift constitution principles exercised by this change, e.g. Principle III (test-first), V (diagnostics), VI (STL to machine-ready G-code). -->

- Principle(s):

## Verification

- [ ] `Scripts/ci.sh` is green (format lint, DocC gate, offline audit, build, all 16 package suites)
- [ ] New behaviour has a Swift Testing test that failed before the fix
- [ ] No test is disabled, skipped, or weakened to make the build pass
- [ ] Concurrency checks are not bypassed; no new `@unchecked Sendable` without written justification
- [ ] Generated-file fixtures were reviewed as production output where output changed
- [ ] Sandbox entitlements and ad-hoc signing are unchanged where the app bundle is affected

## Evidence

<!-- Link measured evidence records, timings, audit notes, or manual verification steps. -->

## Human verification still owed

<!-- List any desktop-only step (VoiceOver walkthrough, controller check, full-session network sample) and who will perform it. -->
