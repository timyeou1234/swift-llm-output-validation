# Provenance

This example was adapted from the proposal-validation boundary in **Moment**,
Timothy Yu's private, in-development iOS project. It is not a verbatim export,
not wire-compatible with the full app, and contains no prior employer code.

The original design separates proposal DTOs, validation, compilation into domain
commands, and user acceptance. It limits what models may propose and prevents
candidate text from becoming an accepted action outcome.

This sample keeps only action checklists and invitation drafts. It omits broader
result families, cross-artifact references, assumption handling, migrations,
networking, UI, persistence, credentials, and external actions.

The following are standalone demonstration choices rather than a claim about
an identical production implementation: explicit unknown-key rejection, a
64 KiB payload cap, sanitized errors, a non-Decodable validated wrapper, and a
local-file demo. This public-ready revision also restricts the schema version
to 1 and uses Unicode-scalar length limits. The schema and tests are written
for this narrowed contract.

The implementation and tests were prepared with AI assistance. The example is
presented as an adaptation, not as unassisted authorship or a full-app test report.

Private repository links, internal issue references, source hashes, local build
paths, and previous application drafts are intentionally not part of this
public example. No access to the private repository is needed to use this package.
