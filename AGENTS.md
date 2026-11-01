# Quizzer

Offline quiz-practice app written in Go with Fyne.
The repository is being bootstrapped; inspect existing files before changing them.

## Context

- docs/product.md: product behavior and MVP requirements.
- docs/question-format.md: JSON question-bank contract.
- docs/architecture.md: architecture and component boundaries; create it
  with the initial implementation.

Read relevant docs when changing the corresponding behavior.
Keep them aligned with implementation; do not duplicate their contents here.

## Build and workflow

- Use modern Bazel with Bzlmod for builds and tests.
- Gazelle/go_deps manages external Go dependencies only.
- Hand-write project BUILD.bazel files; do not run Gazelle over project sources.
- Pin toolchains and dependencies through Bazel. Do not depend on host Go.
- For each change: implement Go logic and tests, update affected BUILD.bazel
  files and documentation, then build/test the affected targets.
- Use bazel build/test, not go build/test, for verification.
- Run only affected targets by default; run broader checks when requested.
- Report the targets checked and any failures or blocked checks.

## Autonomy

You may add dependencies, change pinned versions, define/evolve the JSON
schema, and introduce packages or abstractions when justified by the task.
Keep changes focused and preserve unrelated work.
Update relevant documentation in the same change whenever architecture,
product behavior, or the JSON contract changes.
