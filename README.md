# Swift LLM Output Validation

A small Swift package showing how an iOS app can validate LLM-generated task
proposals before presenting them for review. Adapted from **Moment**, my private,
in-development SwiftUI planning app.

**Valid JSON is not enough.** A response can have the right types and still try
to populate a field that the model should not control.

[繁體中文](README.zh-TW.md)

## The example

The model can suggest “Choose a cake” as a checklist item. It cannot populate
an action outcome with “The cake has already been ordered.” The latter is a
well-formed string, but accepting it would confuse a suggestion with a recorded
result.

This sample supports two output types: an **action checklist** and an
**invitation draft**. It deliberately stops at a reviewable proposal. It does
not save data, run tools, mark work complete, or send anything to an LLM.

```text
JSON bytes
  -> size check
  -> typed decoding / unknown-key rejection
  -> version and product-rule validation
  -> ValidatedTaskModelProposal
  -> caller-owned review and acceptance (outside this package)
```

## Run it

Install Swift 6.0 or later, clone this repository, and enter the package directory:

```sh
git clone https://github.com/timyeou1234/swift-llm-output-validation.git
cd swift-llm-output-validation
```

Build and test both configurations, then try the local examples:

```sh
swift build -c release
swift test --enable-code-coverage
swift test -c release
swift run proposal-demo Examples/checklist.json
swift run proposal-demo Examples/invitation.json
swift run proposal-demo Examples/invalid-outcome.json
```

The first two demos print `Accepted for review`. The last prints
`Rejected: invalidCandidate` and exits with code 1; that rejection is intentional.
To check all three expected outcomes in one command:

```sh
bash scripts/check-examples.sh
```

No package dependencies, API key, model account, or network connection is needed
to build or test after installing the Swift toolchain. The library uses Foundation;
the demo executable only reads local files.

## Use the library

```swift
import Foundation
import MomentLLMValidation

let payload = try Data(contentsOf: URL(fileURLWithPath: "Examples/checklist.json"))
let proposal = try ProposalValidator.decode(payload)
// Pass proposal to a review screen; validation is not user acceptance.
```

`ValidatedTaskModelProposal` has no public initializer and is not `Decodable`.
The intended API makes callers pass through validation instead of decoding
network bytes directly into accepted application state.

## What is checked

| Layer | Checks |
| --- | --- |
| Input | 64 KiB decoding budget, valid JSON, required fields, known keys, closed enum values |
| Contract | Only schema version 1; 1–4 artifacts; unique IDs; contiguous display order |
| Product model | Compatible family, semantic type and renderer; exact field roles and required flags |
| Candidate values | Matching types, bounded text/items, unique nonempty list items |
| Ownership rule | Checklist suggestions are allowed; model-authored action outcomes are rejected |

Text length limits count Unicode scalars, matching the structural schema's
code-point length semantics. The `userConfirmedOrder` wire name is retained from
the original design; receiving that field does **not** prove that a user has
confirmed anything.

The [structural JSON Schema](Examples/proposal.schema.json) documents the wire
shape. Both the checklist and the invalid-outcome example satisfy that schema;
the Swift validator adds the product-specific rejection. It is not a provider
request configuration or a claim that every provider supports the schema.

## Where to start reading

- [ProposalValidation.swift](Sources/MomentLLMValidation/ProposalValidation.swift):
  immutable wire types, closed decoding, validation, and the validated wrapper.
- [ProposalValidationTests.swift](Tests/MomentLLMValidationTests/ProposalValidationTests.swift):
  accepted/rejected cases and boundary tests.
- [Demo](Sources/ProposalDemo/main.swift): the small executable integration.

The core is intentionally one small file so the complete validation path is easy
to review. UI, transport, storage, and provider adapters do not belong in this
layer. When adding a supported shape, update its enum, compatibility rules,
fixtures, and rejection tests together. Adding a case does not automatically
authorize it for every field or renderer.

## Tests and CI

There are **34 XCTest cases**, covering valid input, malformed and unsupported
input, identity/order rules, field compatibility, outcome protection, Unicode
limits, exact byte limits, and decoded DTOs that still fail product validation.
They use local data rather than real model responses.

[GitHub Actions](.github/workflows/swift.yml) is configured to build and test the
package on Linux and macOS and run all three demo fixtures. Local verification
and the limits of that verification are recorded in
[docs/VERIFICATION.md](docs/VERIFICATION.md). A workflow file is not a claim that
a remote CI run has passed.

## Scope

This is an educational adaptation, not the complete Moment app or an SDK for
production deployment. It does not validate factual accuracy, block every prompt
injection, detect raw duplicate JSON member names, or verify external actions.
Text remains untrusted and must be rendered as data, not executed.

The library's size guard applies to an already-received `Data` value. Transport
streaming limits are a separate responsibility; the demo bounds its local file
read. User confirmation, persistence, recovery, and external side effects remain
outside this package.

See [provenance](docs/PROVENANCE.md) for what was adapted. This repository contains
no employer code, API credentials, or private customer data. No open-source
license has been selected; see [NOTICE.md](NOTICE.md).
