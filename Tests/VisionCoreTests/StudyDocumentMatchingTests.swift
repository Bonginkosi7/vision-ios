import XCTest
@testable import VisionCore

final class StudyDocumentMatchingTests: XCTestCase {
    func test_noFiltersMatchesEverything() {
        XCTAssertTrue(StudyDocumentMatching.matches(title: "Anything", subject: nil, taxonomy: StudyDocumentTaxonomy(), filters: StudyDocumentSearchFilters()))
    }

    func test_matchingLevelGradeSubject() {
        let taxonomy = StudyDocumentTaxonomy(level: .basicEducation, grade: "10", subject: "Mathematics")
        XCTAssertTrue(StudyDocumentMatching.matches(
            title: "Algebra notes", subject: "Mathematics", taxonomy: taxonomy,
            filters: StudyDocumentSearchFilters(level: .basicEducation, grade: "10", subject: "Mathematics")
        ))
    }

    func test_mismatchedGradeOrLevelFails() {
        let taxonomy = StudyDocumentTaxonomy(level: .basicEducation, grade: "10", subject: "Mathematics")
        XCTAssertFalse(StudyDocumentMatching.matches(title: "Algebra notes", subject: "Mathematics", taxonomy: taxonomy, filters: StudyDocumentSearchFilters(grade: "11")))
        XCTAssertFalse(StudyDocumentMatching.matches(title: "Algebra notes", subject: "Mathematics", taxonomy: taxonomy, filters: StudyDocumentSearchFilters(level: .higherEducation)))
    }

    func test_queryMatchesTitleOrSubjectCaseInsensitively() {
        let empty = StudyDocumentTaxonomy()
        XCTAssertTrue(StudyDocumentMatching.matches(title: "Algebra Notes", subject: nil, taxonomy: empty, filters: StudyDocumentSearchFilters(query: "algebra")))
        XCTAssertTrue(StudyDocumentMatching.matches(title: "Chapter 1", subject: "Mathematics", taxonomy: empty, filters: StudyDocumentSearchFilters(query: "math")))
        XCTAssertFalse(StudyDocumentMatching.matches(title: "Chapter 1", subject: "Mathematics", taxonomy: empty, filters: StudyDocumentSearchFilters(query: "physics")))
    }

    func test_yearAndLanguageFilters() {
        let taxonomy = StudyDocumentTaxonomy(year: 2023, language: "English")
        XCTAssertTrue(StudyDocumentMatching.matches(title: "Paper", subject: nil, taxonomy: taxonomy, filters: StudyDocumentSearchFilters(year: 2023, language: "English")))
        XCTAssertFalse(StudyDocumentMatching.matches(title: "Paper", subject: nil, taxonomy: taxonomy, filters: StudyDocumentSearchFilters(year: 2022)))
    }
}
