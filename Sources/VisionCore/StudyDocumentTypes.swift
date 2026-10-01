import Foundation

/// Direct port of StudyFileType/StudyDocumentStatus (StudyDocument.kt) —
/// pure data, no platform dependency, so it's real-verified without
/// Xcode the same way RewardRules/FocusDomainMatcher are.
public enum StudyFileType: String, Codable, CaseIterable {
    case pdf = "pdf"
    case docx = "docx"
    case txt = "txt"

    public var label: String {
        switch self {
        case .pdf: return "PDF"
        case .docx: return "DOCX"
        case .txt: return "TXT"
        }
    }
}

public enum StudyDocumentStatus: String, Codable {
    case uploaded = "UPLOADED"
    case processing = "PROCESSING"
    case processed = "PROCESSED"
    case failed = "FAILED"
}
