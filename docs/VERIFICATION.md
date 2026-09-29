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
| Structural JSON Schema (Draft 2020-12) | All three fixtures passed, including invalid-outcome; Swift separately rejected that outcome |
| Public API compile checks | Direct wrapper initialization and JSON decoding into the wrapper both rejected by the compiler |
| Publication review | 16-file allowlist, sensitive-data scan, relative Markdown links, workflow structure, shell syntax, and staged whitespace checks passed |

These are results from this publication session. The supplied bundle also
recorded an earlier Swift 6.2.1 Linux check; that historical record is not used
as evidence for the publication commit.

## GitHub Actions

[Publication run 36519353338](https://github.com/timyeou1234/swift-llm-output-validation/actions/runs/36519353338)
passed on 2026-09-29 for public commit
[`3874247`](https://github.com/timyeou1234/swift-llm-output-validation/commit/3874247f8ab6eac3d2c671ade06e6bbda685a68f).

| Job | Actual environment | Result |
| --- | --- | --- |
| Linux | Ubuntu 24.04 runner, `swift:6.2.1-noble`, Swift 6.2.1, x86_64 | Release build, 34 Debug tests, 34 Release tests, and all three demo checks passed |
| macOS | `macos-15-arm64` runner image, Apple Swift 6.1.2 | Release build, 34 Debug tests, 34 Release tests, and all three demo checks passed |

Both test configurations reported zero failures. This table records that exact
run, not an assertion about future commits. The documentation update triggers
the same workflow again; see the [latest main runs](https://github.com/timyeou1234/swift-llm-output-validation/actions/workflows/swift.yml?query=branch%3Amain)
for subsequent commit results.

## Clean public clone

The public commit above was cloned over HTTPS into a separate empty directory,
with Git credential helpers and global/system Git configuration disabled.
On Apple Swift 6.4 / macOS 26.6.2, the README's release build, Debug tests with
coverage instrumentation, Release tests, and individual demo commands all
passed their expected outcomes. Both test runs executed 34 XCTest cases with
zero failures; invalid-outcome exited with code 1. The example-check script
also passed and the checkout remained clean.

Anonymous HTTP requests for the repository, README, and invalid-outcome fixture
returned 200, and the downloaded files matched the reviewed files. The package
has no external package dependencies and required no private repository or
uncommitted source files. Local JSON Schema/YAML audit tools were separate
verification utilities, not dependencies of the package or its tests.

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
