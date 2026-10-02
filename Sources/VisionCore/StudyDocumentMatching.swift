import Foundation

/// Pure matching logic shared by both real uses of `StudyDocumentSearchFilters`
/// on Android — `StudyMaterialActivity.docsFor` (browsing, filtered by a
/// handful of taxonomy fields at a time) and `StudyDocumentDbHelper.search`
/// (every field, plus the free-text query against title/subject) are the
/// same real criteria-matching logic there, just applied through two
/// different storage paths (in-memory filter vs. a SQL WHERE clause).
/// Unified into one pure function here since iOS loads every document into
/// memory either way (same as `StudyDocumentStore.list()`'s existing shape),
/// so there's no second SQL-querying path worth keeping separate.
public enum StudyDocumentMatching {
    public static func matches(title: String, subject: String?, taxonomy: StudyDocumentTaxonomy, filters: StudyDocumentSearchFilters) -> Bool {
        if let query = filters.query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            let haystack = [title, subject ?? ""].joined(separator: " ").lowercased()
            if !haystack.contains(query.lowercased()) { return false }
        }
        if let level = filters.level, taxonomy.level != level { return false }
        if let grade = filters.grade, taxonomy.grade != grade { return false }
        if let category = filters.category, taxonomy.category != category { return false }
        if let subjectFilter = filters.subject, taxonomy.subject != subjectFilter { return false }
        if let resourceType = filters.resourceType, taxonomy.resourceType != resourceType { return false }
        if let year = filters.year, taxonomy.year != year { return false }
        if let language = filters.language, taxonomy.language != language { return false }
        return true
    }
}
