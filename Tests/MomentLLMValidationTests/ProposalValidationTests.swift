import Foundation
import XCTest
@testable import MomentLLMValidation

final class ProposalValidationTests: XCTestCase {
    private func checklist(id: String = "birthday.checklist", order: Int = 0) -> [String: Any] {
        [
            "id": id, "family": "act", "semanticType": "action_checklist",
            "userLabel": "Birthday checklist", "userConfirmedOrder": order, "view": "list",
            "fields": [
                ["id": "items", "role": "action_items", "label": "Things to prepare",
                 "valueType": "ordered_items", "required": true,
                 "candidateValue": ["Choose a cake", "Confirm the guest count"]],
                ["id": "outcome", "role": "action_outcome", "label": "What was done",
                 "valueType": "text", "required": true, "candidateValue": NSNull()]
            ]
        ]
    }

    private func invitation() -> [String: Any] {
        [
            "id": "birthday.invitation", "family": "create", "semanticType": "invitation_draft",
            "userLabel": "Invitation draft", "userConfirmedOrder": 0, "view": "draft",
            "fields": [
                ["id": "audience", "role": "draft_audience", "label": "Audience",
                 "valueType": "text", "required": true, "candidateValue": "Family"],
                ["id": "body", "role": "draft_body", "label": "Message",
                 "valueType": "rich_text", "required": true, "candidateValue": "Please join us."]
            ]
        ]
    }

    private func data(artifacts: [[String: Any]], version: Int = 1) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": version, "artifacts": artifacts])
    }

    private func editField(_ index: Int, _ edit: (inout [String: Any]) -> Void) throws -> [String: Any] {
        var artifact = checklist()
        var fields = try XCTUnwrap(artifact["fields"] as? [[String: Any]])
        edit(&fields[index])
        artifact["fields"] = fields
        return artifact
    }

    private func reject(_ data: Data, as expected: ProposalValidationError,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try ProposalValidator.decode(data), file: file, line: line) { error in
            XCTAssertEqual(error as? ProposalValidationError, expected, file: file, line: line)
        }
    }

    func testValidChecklistKeepsOutcomeUnfilled() throws {
        let validated = try ProposalValidator.decode(data(artifacts: [checklist()]))
        XCTAssertEqual(validated.artifacts[0].fields[0].candidateValue,
                       .items(["Choose a cake", "Confirm the guest count"]))
        XCTAssertNil(validated.artifacts[0].fields[1].candidateValue)
    }

    func testValidDraftCanContainSuggestedText() throws {
        let validated = try ProposalValidator.decode(data(artifacts: [invitation()]))
        XCTAssertEqual(validated.artifacts[0].fields[1].candidateValue, .text("Please join us."))
    }

    func testReturnsArtifactsInValidatedOrderWithoutChangingIdentity() throws {
        let validated = try ProposalValidator.decode(data(artifacts: [
            checklist(id: "second", order: 1), checklist(id: "first", order: 0)
        ]))
        XCTAssertEqual(validated.artifacts.map(\.id), ["first", "second"])
    }

    func testMalformedJSONIsRejected() {
        reject(Data("{not-json}".utf8), as: .malformedPayload)
    }

    func testMissingRequiredFieldIsRejected() throws {
        var artifact = checklist()
        artifact.removeValue(forKey: "fields")
        reject(try data(artifacts: [artifact]), as: .malformedPayload)
    }

    func testWrongPrimitiveTypeIsRejected() throws {
        var artifact = checklist()
        artifact["userConfirmedOrder"] = "first"
        reject(try data(artifacts: [artifact]), as: .malformedPayload)
    }

    func testUnrecognizedEnumIsRejected() throws {
        var artifact = checklist()
        artifact["view"] = "javascript_renderer"
        reject(try data(artifacts: [artifact]), as: .malformedPayload)
    }

    func testUnexpectedRootKeyIsRejected() throws {
        let payload: [String: Any] = ["schemaVersion": 1, "artifacts": [checklist()], "completed": true]
        reject(try JSONSerialization.data(withJSONObject: payload), as: .malformedPayload)
    }

    func testUnexpectedArtifactKeyIsRejected() throws {
        var artifact = checklist()
        artifact["completed"] = true
        reject(try data(artifacts: [artifact]), as: .malformedPayload)
    }

    func testUnexpectedFieldKeyIsRejected() throws {
        let artifact = try editField(0) { $0["execute"] = "send_message" }
        reject(try data(artifacts: [artifact]), as: .malformedPayload)
    }

    func testUnsupportedSchemaVersionsAreRejected() throws {
        for version in [-1, 0, 2, 99] {
            reject(try data(artifacts: [checklist()], version: version), as: .invalidSchemaVersion)
        }
    }

    func testArtifactCountIsBounded() throws {
        reject(try data(artifacts: []), as: .artifactLimit)
        reject(try data(artifacts: (0..<5).map { checklist(id: "task.\($0)", order: $0) }),
               as: .artifactLimit)
    }

    func testDuplicateArtifactIdentityIsRejected() throws {
        reject(try data(artifacts: [checklist(order: 0), checklist(order: 1)]), as: .duplicateIdentity)
    }

    func testOrderMustBeUniqueAndContiguous() throws {
        reject(try data(artifacts: [checklist(order: 1)]), as: .invalidOrder)
        reject(try data(artifacts: [checklist(id: "one"), checklist(id: "two")]), as: .invalidOrder)
    }

    func testFamilyAndSemanticTypeMustAgree() throws {
        var artifact = checklist()
        artifact["family"] = "create"
        // Valid JSON and Decodable, but not a valid task model.
        XCTAssertNoThrow(try JSONDecoder().decode(TaskModelProposal.self, from: data(artifacts: [artifact])))
        reject(try data(artifacts: [artifact]), as: .invalidFamily)
    }

    func testFamilyAndRendererMustAgree() throws {
        var artifact = checklist()
        artifact["view"] = "draft"
        reject(try data(artifacts: [artifact]), as: .invalidFamily)
    }

    func testArtifactIdentifierAndLabelAreValidated() throws {
        for badID in ["", "1starts-with-digit", "task/execute"] {
            var artifact = checklist()
            artifact["id"] = badID
            reject(try data(artifacts: [artifact]), as: .invalidArtifact)
        }
        for badLabel in ["", " padded ", String(repeating: "x", count: 81)] {
            var artifact = checklist()
            artifact["userLabel"] = badLabel
            reject(try data(artifacts: [artifact]), as: .invalidArtifact)
        }
    }

    func testFieldIdentitiesAndRolesCannotRepeat() throws {
        let duplicateID = try editField(1) { $0["id"] = "items" }
        reject(try data(artifacts: [duplicateID]), as: .invalidArtifact)
        let duplicateRole = try editField(1) { $0["role"] = "action_items" }
        reject(try data(artifacts: [duplicateRole]), as: .invalidArtifact)
    }

    func testRequiredRolesCannotBeOmitted() throws {
        var artifact = checklist()
        let fields = try XCTUnwrap(artifact["fields"] as? [[String: Any]])
        artifact["fields"] = Array(fields.prefix(1))
        reject(try data(artifacts: [artifact]), as: .invalidField)
    }

    func testFieldRoleControlsValueTypeAndRequiredFlag() throws {
        let wrongType = try editField(0) { $0["valueType"] = "text" }
        reject(try data(artifacts: [wrongType]), as: .invalidField)
        let notRequired = try editField(0) { $0["required"] = false }
        reject(try data(artifacts: [notRequired]), as: .invalidField)
    }

    func testCandidateValueMustMatchDeclaredType() throws {
        let artifact = try editField(0) { $0["candidateValue"] = "not an item array" }
        reject(try data(artifacts: [artifact]), as: .invalidCandidate)
    }

    func testModelCannotPrepopulateAnActionOutcome() throws {
        let artifact = try editField(1) { $0["candidateValue"] = "The cake has already been ordered." }
        // The payload even has the correct field type; the product rule still rejects it.
        XCTAssertNoThrow(try JSONDecoder().decode(TaskModelProposal.self, from: data(artifacts: [artifact])))
        reject(try data(artifacts: [artifact]), as: .invalidCandidate)
    }

    func testCandidateItemsAreBoundedNonemptyAndUnique() throws {
        let invalidArrays: [[String]] = [
            [], ["same", "same"], ["  "], [String(repeating: "a", count: 501)],
            (0..<21).map { "item-\($0)" }
        ]
        for invalid in invalidArrays {
            let artifact = try editField(0) { $0["candidateValue"] = invalid }
            reject(try data(artifacts: [artifact]), as: .invalidCandidate)
        }
    }

    func testPayloadBudgetIsEnforced() {
        reject(Data(repeating: 32, count: ProposalValidator.maximumPayloadBytes + 1), as: .payloadTooLarge)
    }
    func testCandidateMayBeOmitted() throws {
        let artifact = try editField(1) { $0.removeValue(forKey: "candidateValue") }
        let validated = try ProposalValidator.decode(data(artifacts: [artifact]))
        XCTAssertNil(validated.artifacts[0].fields[1].candidateValue)
    }

    func testMarkdownWrappedJSONIsRejected() throws {
        let json = String(decoding: try data(artifacts: [checklist()]), as: UTF8.self)
        reject(Data(("```json\n" + json + "\n```").utf8), as: .malformedPayload)
    }

    func testUnsupportedCandidateShapeIsRejected() throws {
        for value: Any in [42, true, ["status": "done"]] {
            let artifact = try editField(0) { $0["candidateValue"] = value }
            reject(try data(artifacts: [artifact]), as: .malformedPayload)
        }
    }

    func testCandidateTextLimitsAreEnforced() throws {
        for text in ["", " padded ", String(repeating: "x", count: 4_001)] {
            var artifact = invitation()
            var fields = try XCTUnwrap(artifact["fields"] as? [[String: Any]])
            fields[1]["candidateValue"] = text
            artifact["fields"] = fields
            reject(try data(artifacts: [artifact]), as: .invalidCandidate)
        }
    }

    func testLabelLimitCountsUnicodeScalars() throws {
        // One visible grapheme can contain multiple scalars; match JSON Schema length semantics.
        var artifact = checklist()
        artifact["userLabel"] = String(repeating: "e\u{0301}", count: 41)
        reject(try data(artifacts: [artifact]), as: .invalidArtifact)
    }

    func testFieldCountIsBounded() throws {
        var artifact = checklist()
        let fields = try XCTUnwrap(artifact["fields"] as? [[String: Any]])
        for tooManyOrFew in [[], Array(repeating: fields[0], count: 13)] {
            artifact["fields"] = tooManyOrFew
            reject(try data(artifacts: [artifact]), as: .invalidArtifact)
        }
    }

    func testMaximumAllowedItemsAreAccepted() throws {
        let items = (0..<20).map { String(repeating: "a", count: 496) + String(format: "%04d", $0) }
        let artifact = try editField(0) { $0["candidateValue"] = items }
        let validated = try ProposalValidator.decode(data(artifacts: [artifact]))
        XCTAssertEqual(validated.artifacts[0].fields[0].candidateValue, .items(items))
    }

    func testMaximumArtifactCountIsAccepted() throws {
        let artifacts = (0..<4).map { checklist(id: "task.\($0)", order: $0) }
        XCTAssertEqual(try ProposalValidator.decode(data(artifacts: artifacts)).artifacts.count, 4)
    }

    func testAlreadyDecodedDTOStillRequiresProductValidation() throws {
        let artifact = try editField(1) { $0["candidateValue"] = "Already booked." }
        let decoded = try JSONDecoder().decode(TaskModelProposal.self, from: data(artifacts: [artifact]))
        XCTAssertThrowsError(try ProposalValidator.validate(decoded)) { error in
            XCTAssertEqual(error as? ProposalValidationError, .invalidCandidate)
        }
    }

    func testExactlyTheByteBudgetIsAccepted() throws {
        var payload = try data(artifacts: [checklist()])
        payload.append(Data(repeating: 32, count: ProposalValidator.maximumPayloadBytes - payload.count))
        XCTAssertNoThrow(try ProposalValidator.decode(payload))
        payload.append(32)
        reject(payload, as: .payloadTooLarge)
    }

}
