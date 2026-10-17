import Foundation

/// Something a person can report: a listing, a message, or another person.
struct ReportTarget: Identifiable {
    // Raw values mirror the report_target enum in supabase/migrations.
    enum Kind: String, Decodable {
        case item, user, message
    }

    let kind: Kind
    let id: UUID
    /// The person responsible, offered for blocking along with the report.
    let userID: UUID
    let name: String?
}

enum ReportReason: String, CaseIterable, Identifiable {
    case prohibited, scam, harassment, inappropriate, safety, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prohibited: "Prohibited item"
        case .scam: "Spam or scam"
        case .harassment: "Harassment or hate"
        case .inappropriate: "Inappropriate content"
        case .safety: "Safety concern"
        case .other: "Other"
        }
    }
}

struct BlockedPerson: Identifiable {
    let id: UUID
    let name: String
    let blockedAt: Date
}

/// The open reports on one thing, as moderators see them.
struct ModerationCase: Identifiable, Decodable {
    let targetType: ReportTarget.Kind
    let targetID: UUID
    /// The listing's owner, the message's sender, or the reported person. Nil if already deleted.
    let subjectID: UUID?
    let subjectName: String?
    let subjectBanned: Bool
    /// The listing title, the message, or the person's name. Nil if already deleted.
    let summary: String?
    let photo: String?
    let reportCount: Int
    let reasons: [String]
    let firstReportedAt: Date

    var id: UUID { targetID }

    enum CodingKeys: String, CodingKey {
        case targetType = "target_type"
        case targetID = "target_id"
        case subjectID = "subject_id"
        case subjectName = "subject_name"
        case subjectBanned = "subject_banned"
        case summary, photo
        case reportCount = "report_count"
        case reasons
        case firstReportedAt = "first_reported_at"
    }
}

enum ModerationAction: String {
    case dismiss, remove, ban
}
