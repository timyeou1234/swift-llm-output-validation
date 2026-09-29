import Foundation

// A small, standalone adaptation of Moment's CaptureTaskModelProposal validation.
// Only checklist and invitation-draft proposals are included in this sample.

public enum ProposalValidationError: Error, Equatable, Sendable {
    case payloadTooLarge
    case malformedPayload
    case invalidSchemaVersion
    case artifactLimit
    case duplicateIdentity
    case invalidOrder
    case invalidArtifact
    case invalidFamily
    case invalidField
    case invalidCandidate
}

public enum ArtifactFamily: String, Decodable, Sendable {
    case act, create
}

public enum ArtifactSemanticType: String, Decodable, Sendable {
    case actionChecklist = "action_checklist"
    case invitationDraft = "invitation_draft"
}

public enum ArtifactView: String, Decodable, Sendable {
    case form, list, draft
    case checklistTimeline = "checklist_timeline"
}

public enum FieldRole: String, Decodable, Sendable {
    case actionItems = "action_items"
    case actionOutcome = "action_outcome"
    case draftAudience = "draft_audience"
    case draftBody = "draft_body"
}

public enum FieldValueType: String, Decodable, Sendable {
    case text
    case richText = "rich_text"
    case orderedItems = "ordered_items"
}

public enum CandidateValue: Decodable, Equatable, Sendable {
    case text(String)
    case items([String])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .items(try container.decode([String].self))
        }
    }
}

public struct FieldProposal: Decodable, Equatable, Sendable {
    public let id: String
    public let role: FieldRole
    public let label: String
    public let valueType: FieldValueType
    public let required: Bool
    public let candidateValue: CandidateValue?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, role, label, valueType, required, candidateValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.closedContainer(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(FieldRole.self, forKey: .role)
        label = try container.decode(String.self, forKey: .label)
        valueType = try container.decode(FieldValueType.self, forKey: .valueType)
        required = try container.decode(Bool.self, forKey: .required)
        candidateValue = try container.decodeIfPresent(CandidateValue.self, forKey: .candidateValue)
    }
}

public struct ArtifactProposal: Decodable, Equatable, Sendable {
    public let id: String
    public let family: ArtifactFamily
    public let semanticType: ArtifactSemanticType
    public let userLabel: String
    public let userConfirmedOrder: Int
    public let view: ArtifactView
    public let fields: [FieldProposal]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, family, semanticType, userLabel, userConfirmedOrder, view, fields
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.closedContainer(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        family = try container.decode(ArtifactFamily.self, forKey: .family)
        semanticType = try container.decode(ArtifactSemanticType.self, forKey: .semanticType)
        userLabel = try container.decode(String.self, forKey: .userLabel)
        userConfirmedOrder = try container.decode(Int.self, forKey: .userConfirmedOrder)
        view = try container.decode(ArtifactView.self, forKey: .view)
        fields = try container.decode([FieldProposal].self, forKey: .fields)
    }
}

// A decoded DTO is not yet an approved application model.
public struct TaskModelProposal: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let artifacts: [ArtifactProposal]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, artifacts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.closedContainer(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        artifacts = try container.decode([ArtifactProposal].self, forKey: .artifacts)
    }
}

// Not Decodable: callers obtain this value only through ProposalValidator.
// Validated means eligible for review, not accepted, persisted, or completed.
public struct ValidatedTaskModelProposal: Equatable, Sendable {
    public let schemaVersion: Int
    public let artifacts: [ArtifactProposal]

    fileprivate init(schemaVersion: Int, artifacts: [ArtifactProposal]) {
        self.schemaVersion = schemaVersion
        self.artifacts = artifacts
    }
}

public enum ProposalValidator {
    public static let supportedSchemaVersion = 1

    // A sample-specific input budget; transport streaming limits are outside this package.
    public static let maximumPayloadBytes = 65_536

    public static func decode(_ data: Data) throws -> ValidatedTaskModelProposal {
        guard data.count <= maximumPayloadBytes else {
            throw ProposalValidationError.payloadTooLarge
        }
        let proposal: TaskModelProposal
        do {
            proposal = try JSONDecoder().decode(TaskModelProposal.self, from: data)
        } catch {
            // Avoid including raw model text in user-visible errors or logs.
            throw ProposalValidationError.malformedPayload
        }
        return try validate(proposal)
    }

    public static func validate(_ proposal: TaskModelProposal) throws -> ValidatedTaskModelProposal {
        guard proposal.schemaVersion == supportedSchemaVersion else {
            throw ProposalValidationError.invalidSchemaVersion
        }
        guard (1...4).contains(proposal.artifacts.count) else {
            throw ProposalValidationError.artifactLimit
        }
        guard Set(proposal.artifacts.map(\.id)).count == proposal.artifacts.count else {
            throw ProposalValidationError.duplicateIdentity
        }
        let orders = Set(proposal.artifacts.map(\.userConfirmedOrder))
        guard orders.count == proposal.artifacts.count,
              orders == Set(proposal.artifacts.indices) else {
            throw ProposalValidationError.invalidOrder
        }
        for artifact in proposal.artifacts {
            try validateArtifact(artifact)
        }
        return ValidatedTaskModelProposal(
            schemaVersion: proposal.schemaVersion,
            artifacts: proposal.artifacts.sorted { $0.userConfirmedOrder < $1.userConfirmedOrder }
        )
    }

    private static func validateArtifact(_ artifact: ArtifactProposal) throws {
        guard validIdentifier(artifact.id), validText(artifact.userLabel, maximum: 80),
              (1...12).contains(artifact.fields.count),
              Set(artifact.fields.map(\.id)).count == artifact.fields.count,
              Set(artifact.fields.map(\.role)).count == artifact.fields.count else {
            throw ProposalValidationError.invalidArtifact
        }

        let requiredRoles: Set<FieldRole>
        switch (artifact.family, artifact.semanticType, artifact.view) {
        case (.act, .actionChecklist, .form),
             (.act, .actionChecklist, .list),
             (.act, .actionChecklist, .checklistTimeline):
            requiredRoles = [.actionItems, .actionOutcome]
        case (.create, .invitationDraft, .draft), (.create, .invitationDraft, .form):
            requiredRoles = [.draftAudience, .draftBody]
        default:
            throw ProposalValidationError.invalidFamily
        }
        guard Set(artifact.fields.map(\.role)) == requiredRoles else {
            throw ProposalValidationError.invalidField
        }

        for field in artifact.fields {
            let typeMatches: Bool = switch field.role {
            case .actionItems: field.valueType == .orderedItems
            case .actionOutcome: field.valueType == .text || field.valueType == .richText
            case .draftAudience: field.valueType == .text
            case .draftBody: field.valueType == .richText
            }
            guard validIdentifier(field.id), validText(field.label, maximum: 80),
                  field.required, typeMatches else {
                throw ProposalValidationError.invalidField
            }
            guard validCandidate(field.candidateValue, for: field.valueType) else {
                throw ProposalValidationError.invalidCandidate
            }
            // A model may suggest checklist items; it may not claim the action was done.
            if field.candidateValue != nil, artifact.family != .create,
               field.valueType != .orderedItems {
                throw ProposalValidationError.invalidCandidate
            }
        }
    }

    private static func validCandidate(_ candidate: CandidateValue?, for type: FieldValueType) -> Bool {
        guard let candidate else { return true }
        switch (type, candidate) {
        case (.text, .text(let text)), (.richText, .text(let text)):
            return validText(text, maximum: 4_000)
        case (.orderedItems, .items(let items)):
            return (1...20).contains(items.count)
                && Set(items).count == items.count
                && items.allSatisfy { validText($0, maximum: 500) }
        default:
            return false
        }
    }

    private static func validText(_ value: String, maximum: Int) -> Bool {
        !value.isEmpty && value.unicodeScalars.count <= maximum
            && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validIdentifier(_ value: String) -> Bool {
        guard (1...64).contains(value.count), let first = value.unicodeScalars.first,
              CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz").contains(first) else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-_")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

// Codable's normal synthesized decoding is not an extra-key validation policy.
// This sample explicitly rejects unknown object keys at each supported level.
private struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension Decoder {
    func closedContainer<K: CodingKey & CaseIterable>(keyedBy type: K.Type)
        throws -> KeyedDecodingContainer<K> {
        let raw = try container(keyedBy: AnyKey.self)
        let allowed = Set(K.allCases.map(\.stringValue))
        guard raw.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath, debugDescription: "Unexpected proposal field"
            ))
        }
        return try container(keyedBy: type)
    }
}
