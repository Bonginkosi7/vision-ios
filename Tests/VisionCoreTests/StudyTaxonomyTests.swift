import XCTest
@testable import VisionCore

/// Direct port of real StudyTaxonomy.kt cases (vision-android).
final class StudyTaxonomyTests: XCTestCase {
    func test_basicEducationHasNoCategories() {
        XCTAssertTrue(StudyTaxonomy.categories(forLevel: .basicEducation).isEmpty)
    }

    func test_higherEducationAndProfessionalHaveRealCategories() {
        XCTAssertFalse(StudyTaxonomy.categories(forLevel: .higherEducation).isEmpty)
        XCTAssertFalse(StudyTaxonomy.categories(forLevel: .professional).isEmpty)
    }

    func test_resourceTypeLabelAndEmoji() {
        XCTAssertEqual(StudyTaxonomy.resourceTypeLabel("textbook"), "Textbooks")
        XCTAssertEqual(StudyTaxonomy.resourceTypeLabel(nil), "")
        XCTAssertEqual(StudyTaxonomy.resourceTypeLabel("mystery"), "mystery")
        XCTAssertEqual(StudyTaxonomy.resourceTypeEmoji("video"), "🎥")
        XCTAssertEqual(StudyTaxonomy.resourceTypeEmoji("mystery"), "📄")
    }

    func test_gradeLabel() {
        XCTAssertEqual(StudyTaxonomy.gradeLabel("12"), "Grade 12")
        XCTAssertEqual(StudyTaxonomy.gradeLabel(nil), "")
    }

    func test_realOptionLists() {
        XCTAssertEqual(studyGrades.count, 6)
        XCTAssertFalse(basicEducationSubjects.isEmpty)
        XCTAssertFalse(studyLanguages.isEmpty)
    }

    func test_hasRealCriteria() {
        XCTAssertFalse(StudyDocumentSearchFilters().hasRealCriteria)
        XCTAssertFalse(StudyDocumentSearchFilters(query: "   ").hasRealCriteria)
        XCTAssertTrue(StudyDocumentSearchFilters(query: "algebra").hasRealCriteria)
        XCTAssertTrue(StudyDocumentSearchFilters(level: .basicEducation).hasRealCriteria)
    }
}
