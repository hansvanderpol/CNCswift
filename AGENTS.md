# AGENTS.md

## Coding standards
- Write clean, maintainable code.
- Follow existing project conventions.
- Avoid unnecessary dependencies.
- Handle errors properly.
- Never silently remove existing functionality.
- Keep changes focused.

## Agent behaviour
- Use terminal tools when needed.
- Read relevant files before editing.
- Continue working until the requested task is complete.
- Do not stop after merely proposing a solution.
- Verify that the implementation works.
- Report anything that could not be verified.

## Safety
- Ask before deleting important files.
- Ask before deploying or publishing.
- Never expose secrets or API keys.
- Never execute destructive commands without approval.

## Repository state
- This is a Spec-Driven Development (SDD) workspace created by GitHub Spec Kit 1.3.3 with the OpenCode integration. It now contains a git repository, the `001-stl-to-gcode` feature artifacts, and a Swift Package Manager workspace.
- The stack is Swift 6.4.2 / macOS 27 (arm64) with SwiftUI and RealityKit; Command Line Tools is the active developer directory (Xcode is unavailable). The root `Package.swift` aggregates sixteen local packages under `Packages/` plus the `CNCswiftApp` executable under `App/Sources/`.
- `.idea/` exists but there is no Java build; do not infer a JVM stack from it.
- Feature onboarding and validation scenarios are recorded in `specs/001-stl-to-gcode/quickstart.md`; the executable gates are in `Scripts/ci.sh` and `Scripts/make-app.sh`.

## Build, lint, and test commands (verified on this machine)
Run from the repository root:

```bash
Scripts/ci.sh                       # format lint, DocC gate, offline audit, workspace build, then all 16 package test suites
swift build                         # build the workspace and CNCswiftApp
swift format lint --configuration .swift-format --recursive Package.swift App Packages
python3 Scripts/check-docc.py        # fail when a public declaration lacks an immediately preceding DocC comment
swift format format --configuration .swift-format --in-place --recursive Package.swift App Packages
PLUGIN="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
swift test --package-path Packages/<Module> -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN"
Scripts/make-app.sh                 # assemble and ad-hoc sign .build/CNCswift.app
codesign -dvv .build/CNCswift.app
codesign -d --entitlements :- .build/CNCswift.app
```

- `swift test` from the root reports "no tests found": SwiftPM only runs the root package's tests, and each local package owns its test target. Test each package with `--package-path`; `Scripts/ci.sh` loops over all sixteen.
- Swift Testing's macro plugin is not on SwiftPM's default search path under Command Line Tools, so every `swift test` invocation needs `-load-plugin-library` with the plugin path above.
- Build output lives under `.build/out/`; `.build/debug` is a symlink to `.build/out/Products/Debug`.

## Workflow
Commands are OpenCode slash commands invoked as `/speckit.<name>`:

- `/speckit.constitution` — create or update project principles.
- `/speckit.specify` — create `specs/NNN-<short-name>/spec.md` and set the current feature.
- `/speckit.clarify` — resolve underspecified requirements (optional).
- `/speckit.plan` — generate `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/`.
- `/speckit.tasks` — generate dependency-ordered `tasks.md`.
- `/speckit.analyze` / `/speckit.checklist` — optional cross-artifact and requirements-quality reviews.
- `/speckit.implement` — execute `tasks.md` and mark completed tasks `[X]`.
- `/speckit.converge` — append unbuilt work back into `tasks.md`.

Standard path: specify → clarify → plan → tasks → implement. Do not jump to implementation before `plan.md` and `tasks.md` exist.

The registered `speckit` workflow ("Full SDD Cycle") is specify → plan → tasks → implement with review gates; `/speckit.specify` requires a feature description.

## Feature state and layout
- The active feature is persisted in `.specify/feature.json` as `{"feature_directory": "specs/NNN-..."}`. It is machine-local and gitignored.
- Override it with `SPECIFY_FEATURE_DIRECTORY=specs/NNN-...`; downstream scripts read either source.
- Features are numbered sequentially (`001`, `002`, ...) by scanning existing `specs/` directories.
- Inspect state with:
  ```bash
  bash .specify/scripts/bash/check-prerequisites.sh --json --paths-only
  bash .specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ```
  Run scripts from the repo root.

## Generated files
- `.opencode/commands/speckit.*`, `.specify/scripts/bash/*`, and the core `.specify/templates/*.md` are integration-managed; checksums are recorded in `.specify/integrations/*.manifest.json`. Prefer not to hand-edit them.
- Customize via `.specify/templates/overrides/<template>.md`, then `.specify/presets/`, then `.specify/extensions/`. Template resolution order is overrides → presets → extensions → core.
- `.specify/extensions.yml` does not exist, so the hook sections in command files are currently no-ops.

## Script gotchas
- Use `bash`, not `sh`, despite `"script": "sh"` in `.specify/init-options.json`; the scripts use Bash arrays and `[[ ]]`.
- `python3` is required for registry/preset parsing; PyYAML is required only when presets declare template composition. `jq` is optional but preferred.

## Documents and diagrams
All artifact skills have `disable-model-invocation: true`: invoke them only when the user explicitly asks for that artifact. Each uses 3-digit IDs and continues after the highest existing ID.

- `user-stories/US-NNN-*.md`
- `use-cases/UC-NNN-*.md`
- `technical-designs/TD-NNN-*.md` (requires a user story or use case)
- `test-scenarios/TS-NNN-*.md` (requires a user story or use case)
- `data-definitions/DDE-NNN-*.md` (requires user story/use case references)
- Diagram files contain Mermaid code only, no prose:
  - `entity-relationship-diagrams/ERD-NNN-*.md`
  - `flowcharts/FLW-NNN-*.md`
  - `mindmaps/MND-NNN-*.md`
  - `sequence-diagrams/SEQ-NNN-*.md`
  - `state-diagrams/STA-NNN-*.md`
  - `user-journeys/UJR-NNN-*.md`

## k6 scripts
- `test-script-k6` also requires an OpenAPI 3.x document as a second input; reconcile every endpoint, field, and status code against it instead of inventing values.
- Output goes to `test-scripts-k6/<scenario-filename>/`: one `k6-TC-NNN-NNN-<title>.js` per test case, a shared `config.js` for connection settings only, and a short `README.md`.
- Each case must run standalone with `k6 run` and may import only `./config.js`.

## Constitution
- `.specify/memory/constitution.md` holds the active CNCswift constitution (v4.3.0). It is authoritative for architecture, concurrency, test-first, accessibility, diagnostics, dialect, storage, and distribution gates.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. When the answer is under a Markdown heading, `graphify section "<heading>"` prints that section's text, so the .md need not be opened. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.
