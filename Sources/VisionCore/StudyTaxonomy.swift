import Foundation

/// Direct port of desktop's `src/shared/studyTaxonomy.ts` (via Android's
/// own `StudyTaxonomy.kt`) — real, public category/subject *names*
/// (South Africa's CAPS curriculum subjects, real qualification levels)
/// the user assigns to their own uploaded files, never a claim that
/// VISION has actual textbook/past-paper content behind them. Every
/// branch starts genuinely empty until a real file is uploaded and
/// tagged.
public enum StudyLevel: String, Codable, CaseIterable {
    case basicEducation = "BASIC_EDUCATION"
    case higherEducation = "HIGHER_EDUCATION"
    case professional = "PROFESSIONAL"

    public var label: String {
        switch self {
        case .basicEducation: return "Basic Education"
        case .higherEducation: return "Higher Education"
        case .professional: return "Working Professionals"
        }
    }

    public var description: String {
        switch self {
        case .basicEducation: return "Primary & High School"
        case .higherEducation: return "University, TVET & postgraduate study"
        case .professional: return "Certifications, short courses & career development"
        }
    }
}

public struct StudyGradeOption: Equatable {
    public let id: String
    public let label: String
    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

public let studyGrades: [StudyGradeOption] = [
    StudyGradeOption(id: "R-3", label: "Grade R–3"),
    StudyGradeOption(id: "4-6", label: "Grade 4–6"),
    StudyGradeOption(id: "7-9", label: "Grade 7–9"),
    StudyGradeOption(id: "10", label: "Grade 10"),
    StudyGradeOption(id: "11", label: "Grade 11"),
    StudyGradeOption(id: "12", label: "Grade 12"),
]

public let basicEducationSubjects: [String] = [
    "Mathematics", "Mathematical Literacy", "Physical Sciences", "Life Sciences", "Accounting",
    "Business Studies", "Economics", "Geography", "History", "English", "Afrikaans", "isiZulu",
    "isiXhosa", "Sepedi", "Setswana", "Sesotho", "Tshivenda", "Tourism",
    "Computer Applications Technology", "Information Technology", "Agricultural Sciences",
    "Technical Mathematics", "Technical Sciences",
]

public let higherEducationCategories: [String] = [
    "University", "TVET Colleges", "Undergraduate", "Postgraduate", "Academic writing",
    "Research", "Study skills", "Past assessments",
]

public let professionalCategories: [String] = [
    "Professional certifications", "Short courses", "Career development", "Technology & IT",
    "Business", "Finance", "Management", "Compliance", "Professional exams",
]

public struct StudyResourceTypeOption: Equatable {
    public let id: String
    public let label: String
    public let emoji: String
    public init(id: String, label: String, emoji: String) {
        self.id = id
        self.label = label
        self.emoji = emoji
    }
}

public let studyResourceTypes: [StudyResourceTypeOption] = [
    StudyResourceTypeOption(id: "textbook", label: "Textbooks", emoji: "📘"),
    StudyResourceTypeOption(id: "study_guide", label: "Study Guides", emoji: "📄"),
    StudyResourceTypeOption(id: "past_paper", label: "Past Papers", emoji: "📝"),
    StudyResourceTypeOption(id: "memorandum", label: "Memoranda", emoji: "✅"),
    StudyResourceTypeOption(id: "revision", label: "Revision", emoji: "📚"),
    StudyResourceTypeOption(id: "practical", label: "Practical", emoji: "🧪"),
    StudyResourceTypeOption(id: "assessment", label: "Assessments", emoji: "📋"),
    StudyResourceTypeOption(id: "video", label: "Videos", emoji: "🎥"),
    StudyResourceTypeOption(id: "notes", label: "Notes", emoji: "🧠"),
    StudyResourceTypeOption(id: "flashcards", label: "Flashcards", emoji: "🃏"),
    StudyResourceTypeOption(id: "practice", label: "Practice", emoji: "🧩"),
]

public let studyLanguages: [String] = [
    "English", "Afrikaans", "isiZulu", "isiXhosa", "Sesotho", "Setswana", "Sepedi",
    "Tshivenda", "siSwati", "isiNdebele", "Xitsonga",
]

public enum StudyTaxonomy {
    public static func categories(forLevel level: StudyLevel) -> [String] {
        switch level {
        case .higherEducation: return higherEducationCategories
        case .professional: return professionalCategories
        case .basicEducation: return []
        }
    }

    public static func resourceTypeLabel(_ id: String?) -> String {
        guard let id else { return "" }
        return studyResourceTypes.first { $0.id == id }?.label ?? id
    }

    public static func resourceTypeEmoji(_ id: String?) -> String {
        studyResourceTypes.first { $0.id == id }?.emoji ?? "📄"
    }

    public static func gradeLabel(_ id: String?) -> String {
        guard let id else { return "" }
        return studyGrades.first { $0.id == id }?.label ?? id
    }
}

/// Real user-assigned taxonomy on their own uploaded document — never
/// inferred or fabricated. Direct port of `StudyDocumentTaxonomy` (Kotlin).
public struct StudyDocumentTaxonomy: Codable, Equatable {
    public var level: StudyLevel?
    public var grade: String?
    public var category: String?
    public var subject: String?
    public var resourceType: String?
    public var year: Int?
    public var language: String?

    public init(
        level: StudyLevel? = nil, grade: String? = nil, category: String? = nil, subject: String? = nil,
        resourceType: String? = nil, year: Int? = nil, language: String? = nil
    ) {
        self.level = level
        self.grade = grade
        self.category = category
        self.subject = subject
        self.resourceType = resourceType
        self.year = year
        self.language = language
    }
}

/// Real search/filter criteria for browsing tagged study documents —
/// direct port of `StudyDocumentSearchFilters` (Kotlin).
public struct StudyDocumentSearchFilters: Equatable {
    public var query: String?
    public var level: StudyLevel?
    public var grade: String?
    public var category: String?
    public var subject: String?
    public var resourceType: String?
    public var year: Int?
    public var language: String?

    public init(
        query: String? = nil, level: StudyLevel? = nil, grade: String? = nil, category: String? = nil,
        subject: String? = nil, resourceType: String? = nil, year: Int? = nil, language: String? = nil
    ) {
        self.query = query
        self.level = level
        self.grade = grade
        self.category = category
        self.subject = subject
        self.resourceType = resourceType
        self.year = year
        self.language = language
    }

    public var hasRealCriteria: Bool {
        !(query?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            level != nil || grade != nil || category != nil || subject != nil || resourceType != nil || year != nil || language != nil
    }
}
