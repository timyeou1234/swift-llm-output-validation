import Foundation
import MomentLLMValidation

// The demo reads one local JSON file. It does not call a model or write app state.
func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

guard CommandLine.arguments.count == 2 else {
    fail("Usage: proposal-demo <local-json-file>", code: 2)
}

do {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    // Cap the bytes read by the demo as well as the validator's decoding budget.
    let data = try handle.read(upToCount: ProposalValidator.maximumPayloadBytes + 1) ?? Data()
    let proposal = try ProposalValidator.decode(data)
    print("Accepted for review: \(proposal.artifacts.count) artifact(s), schema v\(proposal.schemaVersion).")
    print("Nothing was accepted by a user, persisted, or executed.")
} catch let error as ProposalValidationError {
    fail("Rejected: \(error)", code: 1)
} catch {
    // Do not print file contents or Foundation error payloads.
    fail("Could not read the input file.", code: 2)
}
