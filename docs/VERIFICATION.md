# Verification record

## Publication checks

Local verification on 2026-09-29: Apple Swift 6.4, arm64, macOS 26.6.2.
The original handoff manifest matched all 16 public files before any edits.

| Check | Result |
| --- | --- |
| `swift build -c release` | Passed |
| `swift test --enable-code-coverage` | 34 XCTest cases passed, 0 failures |
| `swift test -c release` | 34 XCTest cases passed, 0 failures |
| `bash scripts/check-examples.sh` | Checklist and invitation accepted for review; invalid outcome rejected with exit 1 |

These are results from this publication session. The supplied bundle also
recorded an earlier Swift 6.2.1 Linux check; that historical record is not used
as evidence for the publication commit.

GitHub Actions and a clean public clone still need to run after publication.
The workflow runs release build, Debug tests with coverage instrumentation,
Release tests, and the three demo checks on Linux and macOS.

## Changes from the supplied bundle

- Added Release tests to both CI jobs.
- Added clone, release build, and both test configurations to the READMEs.
- Corrected a Traditional Chinese spelling and updated this verification record.
- Kept the validator, tests, fixtures, structural schema, provenance, and NOTICE
  unchanged. The original manifest is retained as local handoff evidence.

## Limits

The tests use deterministic local data and do not call a model or the network.
Coverage instrumentation was run; no coverage percentage or full-app coverage
is claimed. iOS Simulator, UI, provider APIs, persistence, and the complete
Moment application were not tested. Validation only makes a proposal eligible
for user review; it does not accept, save, execute, or complete an action.
