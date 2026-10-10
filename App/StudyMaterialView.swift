import SwiftUI
import UniformTypeIdentifiers
import VisionCore

private enum StudyBrowseView: Equatable {
    case home
    case grades
    case categories(StudyLevel)
    case subjects(String)
    case resources(level: StudyLevel, grade: String? = nil, subject: String? = nil, category: String? = nil)
    case search
    case untagged
}

private enum StudyMaterialTab {
    case browse, review
}

/// Real taxonomy browser + tagging + folded-in spaced-repetition Review
/// — port of `StudyMaterialActivity.kt`, itself the Android counterpart
/// of desktop's Study Material hub (`renderer/study/study.ts`). Real,
/// public level/grade/subject/resource-type *names* the user assigns to
/// their own uploaded files; every branch starts genuinely empty until a
/// real file is uploaded and tagged — never fabricated textbook/past-
/// paper content. Documents uploaded via My Materials land here
/// untagged, same real architecture as Android/desktop (a separate
/// upload entry point feeding into this shared, taxonomy-aware hub).
///
/// **Disclosed, deliberate difference from Android.** Android folds
/// "View" and "Download" into one `FileProvider` + `ACTION_VIEW` intent,
/// handing the real file to whatever app the user has installed. iOS's
/// real equivalent of "hand this file to another app" is a share sheet
/// (`ShareLink`), so "Open" here presents one instead — same real app
/// interop philosophy, same real bytes, different OS-native mechanism.
///
/// The Review tab only ever shows offline-saved pages tagged
/// "education" (`OfflineStore.listByCategory`) — real category
/// reassignment now lives on `OfflineLibraryView`'s own rows, the only
/// way a real item can land there.
struct StudyMaterialView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var offlineStore: OfflineStore
    @ObservedObject var studyReviewStore: StudyReviewStore
    let onNavigate: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var tab: StudyMaterialTab = .browse
    @State private var allDocs: [StudyDocument] = []
    @State private var currentView: StudyBrowseView = .home
    @State private var viewHistory: [StudyBrowseView] = []
    @State private var activeFilters = StudyDocumentSearchFilters()
    @State private var searchText = ""
    @State private var showFilterPanel = false
    @State private var showFilePicker = false
    @State private var uploadStatus: String?
    @State private var taggingDoc: StudyDocument?

    @State private var streak = 0
    @State private var dueItems: [(entry: StudyQueueEntry, item: OfflineItem)] = []
    @State private var caughtUpText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSwitcher
                if tab == .browse {
                    browseTab
                } else {
                    reviewTab
                }
            }
            .visionScreen()
            .navigationTitle("Study Material")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("btnAddStudyMaterial")
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, UTType(filenameExtension: "docx") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handlePicked(result)
            }
            .sheet(item: $taggingDoc) { doc in
                TagDocumentSheet(document: doc) { taxonomy in
                    try? studyDocumentStore.setTaxonomy(id: doc.id, taxonomy: taxonomy)
                    taggingDoc = nil
                    refreshDocs()
                }
            }
        }
        .onAppear {
            refreshDocs()
            loadReview()
        }
    }

    // MARK: - Tabs

    @ViewBuilder private var tabSwitcher: some View {
        HStack(spacing: 8) {
            tabButton("Browse", isActive: tab == .browse) { tab = .browse }
                .accessibilityIdentifier("btnStudyTabBrowse")
            tabButton("Review", isActive: tab == .review) { tab = .review; loadReview() }
                .accessibilityIdentifier("btnStudyTabReview")
        }
        .padding(DesignSystem.Space.m)
    }

    @ViewBuilder private func tabButton(_ title: String, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.black : Color.white)
                .padding(.horizontal, DesignSystem.Space.l).frame(minHeight: 36)
                .background(Capsule().fill(isActive ? Color.white : Color.clear))
                .overlay(Capsule().stroke(isActive ? Color.clear : DesignSystem.borderCard, lineWidth: 1))
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Browse

    @ViewBuilder private var browseTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchAndFilterBar
            if showFilterPanel { filterPanel }
            breadcrumbRow
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                    switch currentView {
                    case .home: homeSection
                    case .grades: gradesSection
                    case .categories(let level): categoriesSection(level)
                    case .subjects(let grade): subjectsSection(grade)
                    case .resources(let level, let grade, let subject, let category): resourcesSection(level: level, grade: grade, subject: subject, category: category)
                    case .search: searchSection
                    case .untagged: untaggedSection
                    }
                }
                .padding(DesignSystem.Space.l)
            }
        }
    }

    @ViewBuilder private var searchAndFilterBar: some View {
        HStack(spacing: 8) {
            TextField("", text: $searchText, prompt: Text("Search materials…").foregroundColor(DesignSystem.textMuted2))
                .visionField()
                .accessibilityLabel("Search materials")
                .accessibilityIdentifier("studySearchInput")
                .onChange(of: searchText) { newValue in applySearchText(newValue) }
            Button(action: { showFilterPanel.toggle() }) {
                Image(systemName: "line.3.horizontal.decrease")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("btnStudyFilterToggle")
        }
        .padding(.horizontal, DesignSystem.Space.l).padding(.top, DesignSystem.Space.m)
    }

    @ViewBuilder private var filterPanel: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
            filterPicker("Level", selection: levelBinding, options: [nil] + StudyLevel.allCases, label: { $0?.label ?? "Any" })
            filterPicker("Grade", selection: gradeBinding, options: [nil] + studyGrades.map { $0.id }, label: { $0 == nil ? "Any" : StudyTaxonomy.gradeLabel($0) })
            filterPicker("Subject", selection: subjectBinding, options: [nil] + basicEducationSubjects, label: { $0 ?? "Any" })
            filterPicker("Resource Type", selection: resourceTypeBinding, options: [nil] + studyResourceTypes.map { $0.id }, label: { $0 == nil ? "Any" : StudyTaxonomy.resourceTypeLabel($0) })
            yearField
            filterPicker("Language", selection: languageBinding, options: [nil] + studyLanguages, label: { $0 ?? "Any" })
        }
        .padding(DesignSystem.Space.l)
        .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous).fill(DesignSystem.bgCard))
        .padding(.horizontal, DesignSystem.Space.l).padding(.top, DesignSystem.Space.s)
        .accessibilityIdentifier("studyFilterPanel")
    }

    @ViewBuilder private func filterPicker<T: Hashable>(_ title: String, selection: Binding<T?>, options: [T?], label: @escaping (T?) -> String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder private var yearField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Year").font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
            TextField("", text: Binding(
                get: { activeFilters.year.map(String.init) ?? "" },
                set: { newValue in
                    activeFilters.year = Int(newValue)
                    applyFilterNavigation()
                }
            ), prompt: Text("Any").foregroundColor(DesignSystem.textMuted2))
            .keyboardType(.numberPad)
            .visionField()
            .accessibilityLabel("Year")
            .accessibilityIdentifier("studyFilterYear")
        }
    }

    private var levelBinding: Binding<StudyLevel?> {
        Binding(get: { activeFilters.level }, set: { activeFilters.level = $0; applyFilterNavigation() })
    }
    private var gradeBinding: Binding<String?> {
        Binding(get: { activeFilters.grade }, set: { activeFilters.grade = $0; applyFilterNavigation() })
    }
    private var subjectBinding: Binding<String?> {
        Binding(get: { activeFilters.subject }, set: { activeFilters.subject = $0; applyFilterNavigation() })
    }
    private var resourceTypeBinding: Binding<String?> {
        Binding(get: { activeFilters.resourceType }, set: { activeFilters.resourceType = $0; applyFilterNavigation() })
    }
    private var languageBinding: Binding<String?> {
        Binding(get: { activeFilters.language }, set: { activeFilters.language = $0; applyFilterNavigation() })
    }

    @ViewBuilder private var breadcrumbRow: some View {
        HStack(spacing: 8) {
            if !viewHistory.isEmpty {
                Button("‹ Back") { goBack() }.accessibilityIdentifier("btnStudyBack")
            }
            Text(breadcrumbLabel).font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("studyBreadcrumb")
        }
        .padding(.horizontal, DesignSystem.Space.l).padding(.top, DesignSystem.Space.m)
    }

    private var breadcrumbLabel: String {
        switch currentView {
        case .home: return "Home"
        case .grades: return "Basic Education"
        case .categories(let level): return level.label
        case .subjects(let grade): return StudyTaxonomy.gradeLabel(grade)
        case .resources(_, _, let subject, let category): return subject ?? category ?? ""
        case .search: return "Search Results"
        case .untagged: return "Untagged"
        }
    }

    @ViewBuilder private var homeSection: some View {
        ForEach(StudyLevel.allCases, id: \.self) { level in
            sectionCard(title: level.label, subtitle: level.description, count: docsFor(level: level).count, identifier: "studySection_\(level.rawValue)") {
                navigate(level == .basicEducation ? .grades : .categories(level))
            }
        }
        let untaggedCount = allDocs.filter { $0.level == nil }.count
        if untaggedCount > 0 {
            // Deliberately NO .accessibilityIdentifier on the whole card:
            // a real captured .xcresult dump (Phase 8's own established
            // forensics technique) already proved once this session that
            // an identifier on a container wrapping multiple children
            // doesn't just leak onto plain Text leaves — it can overwrite
            // a child Button's own explicit identifier too. Each real
            // element below carries its own distinct identifier instead.
            DesignSystem.card {
                Text("\(untaggedCount) item\(untaggedCount == 1 ? "" : "s") need\(untaggedCount == 1 ? "s" : "") details")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .accessibilityIdentifier("studyUntaggedBanner")
                Text("Add a level, subject, and more so these show up in the right place.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                Button("Review") { navigate(.untagged) }
                    .padding(.top, DesignSystem.Space.s)
                    .accessibilityIdentifier("btnStudyReviewUntagged")
            }
        }
    }

    @ViewBuilder private var gradesSection: some View {
        ForEach(studyGrades, id: \.id) { grade in
            sectionCard(title: grade.label, subtitle: nil, count: docsFor(level: .basicEducation, grade: grade.id).count, identifier: "studySection_grade_\(grade.id)") {
                navigate(.subjects(grade.id))
            }
        }
    }

    @ViewBuilder private func categoriesSection(_ level: StudyLevel) -> some View {
        ForEach(StudyTaxonomy.categories(forLevel: level), id: \.self) { category in
            sectionCard(title: category, subtitle: nil, count: docsFor(level: level, category: category).count, identifier: "studySection_category_\(category)") {
                navigate(.resources(level: level, category: category))
            }
        }
    }

    @ViewBuilder private func subjectsSection(_ grade: String) -> some View {
        ForEach(basicEducationSubjects, id: \.self) { subject in
            sectionCard(title: subject, subtitle: nil, count: docsFor(level: .basicEducation, grade: grade, subject: subject).count, identifier: "studySection_subject_\(subject)") {
                navigate(.resources(level: .basicEducation, grade: grade, subject: subject))
            }
        }
    }

    @ViewBuilder private func resourcesSection(level: StudyLevel, grade: String?, subject: String?, category: String?) -> some View {
        let docs = docsFor(level: level, grade: grade, subject: subject, category: category)
        if docs.isEmpty {
            Text("No materials here yet.").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2).accessibilityIdentifier("studyEmptyResources")
            Button("Add material") { showFilePicker = true }.accessibilityIdentifier("btnStudyAddFromEmpty")
        } else {
            ForEach(studyResourceTypes, id: \.id) { resourceType in
                let inGroup = docs.filter { $0.resourceType == resourceType.id }
                if !inGroup.isEmpty {
                    DesignSystem.sectionLabel(resourceType.label).padding(.top, DesignSystem.Space.s)
                    ForEach(inGroup) { doc in docRow(doc) }
                }
            }
            let untyped = docs.filter { $0.resourceType == nil }
            if !untyped.isEmpty {
                DesignSystem.sectionLabel("Other").padding(.top, DesignSystem.Space.s)
                ForEach(untyped) { doc in docRow(doc) }
            }
        }
    }

    @ViewBuilder private var searchSection: some View {
        let results = allDocs.filter { StudyDocumentMatching.matches(title: $0.title, subject: $0.subject, taxonomy: $0.taxonomy, filters: activeFilters) }
        if results.isEmpty {
            Text("No matches.").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2).accessibilityIdentifier("studyNoMatches")
        } else {
            ForEach(results) { doc in docRow(doc) }
        }
    }

    @ViewBuilder private var untaggedSection: some View {
        let untagged = allDocs.filter { $0.level == nil }
        if untagged.isEmpty {
            Text("Nothing untagged right now.").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2).accessibilityIdentifier("studyNothingUntagged")
        } else {
            // Deliberately NO .accessibilityIdentifier on the whole HStack
            // row — see homeSection's own comment on this same real
            // container-identifier-clobbers-a-child-Button quirk.
            ForEach(untagged) { doc in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .accessibilityIdentifier("studyUntaggedRow_\(doc.id)")
                        Text(doc.fileType.label).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    }
                    Spacer()
                    Button("Add details") { taggingDoc = doc }.accessibilityIdentifier("btnStudyAddDetails_\(doc.id)")
                }
                .padding(.vertical, DesignSystem.Space.s)
            }
        }
    }

    @ViewBuilder private func sectionCard(title: String, subtitle: String?, count: Int, identifier: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2) }
                Text("\(count) item\(count == 1 ? "" : "s")").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Space.l)
            .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous).fill(DesignSystem.bgCard))
        }
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private func docRow(_ doc: StudyDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .accessibilityIdentifier("studyDocTitle_\(doc.id)")
            let meta = [doc.fileType.label, doc.year.map(String.init), doc.language].compactMap { $0 }.joined(separator: " · ")
            Text(meta).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)

            HStack(spacing: DesignSystem.Space.l) {
                ShareLink(item: URL(fileURLWithPath: doc.contentPath)) {
                    Text("Open").font(.system(size: 13, weight: .semibold))
                }
                .accessibilityIdentifier("btnStudyOpen_\(doc.id)")

                if doc.offlineReadyAt != nil {
                    Text("Offline ready").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("studyOfflineReady_\(doc.id)")
                } else {
                    Button("Mark offline") { markOfflineReady(doc) }
                        .font(.system(size: 13))
                        .accessibilityIdentifier("btnStudyMarkOffline_\(doc.id)")
                }

                Button("Edit tags") { taggingDoc = doc }
                    .font(.system(size: 13))
                    .accessibilityIdentifier("btnStudyEditTags_\(doc.id)")
            }
        }
        .padding(.vertical, DesignSystem.Space.s)
    }

    // MARK: - Review

    @ViewBuilder private var reviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                if streak > 0 {
                    Text("\(streak)-day streak").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .accessibilityIdentifier("studyReviewStreak")
                }
                if dueItems.isEmpty {
                    if let caughtUpText {
                        Text(caughtUpText).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2).accessibilityIdentifier("studyReviewCaughtUp")
                    } else {
                        Text("Nothing to review yet. Save a page offline and tag it \"Education\" from the Offline Library to add it here.")
                            .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("studyReviewEmpty")
                    }
                } else {
                    ForEach(dueItems, id: \.item.id) { entry, item in
                        reviewRow(entry: entry, item: item)
                    }
                }
            }
            .padding(DesignSystem.Space.l)
        }
    }

    @ViewBuilder private func reviewRow(entry: StudyQueueEntry, item: OfflineItem) -> some View {
        DesignSystem.card {
            Button(action: { onNavigate(item.url); dismiss() }) {
                Text(item.title.isEmpty ? item.url : item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            }
            .accessibilityIdentifier("studyReviewRow_\(item.id)")
            Text(entry.reviewCount == 0 ? "Not reviewed yet" : "Reviewed \(entry.reviewCount) time\(entry.reviewCount == 1 ? "" : "s")")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
            HStack(spacing: DesignSystem.Space.l) {
                Button("Again") { markReviewed(item.id, confident: false) }.accessibilityIdentifier("btnStudyReviewAgain_\(item.id)")
                Button("Got it") { markReviewed(item.id, confident: true) }.accessibilityIdentifier("btnStudyReviewGotIt_\(item.id)")
            }
            .padding(.top, DesignSystem.Space.s)
        }
    }

    // MARK: - Actions

    private func navigate(_ view: StudyBrowseView) {
        viewHistory.append(currentView)
        currentView = view
    }

    private func goBack() {
        guard let previous = viewHistory.popLast() else { return }
        currentView = previous
    }

    private func applySearchText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            activeFilters.query = nil
            if currentView == .search { goBack() }
            return
        }
        activeFilters.query = trimmed
        if currentView != .search { navigate(.search) }
    }

    private func applyFilterNavigation() {
        if activeFilters.hasRealCriteria {
            if currentView != .search { navigate(.search) }
        } else if currentView == .search {
            goBack()
        }
    }

    private func docsFor(level: StudyLevel? = nil, grade: String? = nil, subject: String? = nil, category: String? = nil) -> [StudyDocument] {
        let filters = StudyDocumentSearchFilters(level: level, grade: grade, category: category, subject: subject)
        return allDocs.filter { StudyDocumentMatching.matches(title: $0.title, subject: $0.subject, taxonomy: $0.taxonomy, filters: filters) }
    }

    private func refreshDocs() {
        allDocs = (try? studyDocumentStore.list()) ?? []
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let doc = try DocumentImport.importFile(at: url, store: studyDocumentStore)
                refreshDocs()
                taggingDoc = doc
            } catch {
                uploadStatus = error.localizedDescription
            }
        case .failure(let error):
            uploadStatus = error.localizedDescription
        }
    }

    private func markOfflineReady(_ doc: StudyDocument) {
        try? studyDocumentStore.markOfflineReady(id: doc.id)
        refreshDocs()
    }

    private func loadReview() {
        let educationItems = (try? offlineStore.listByCategory("education")) ?? []
        streak = (try? studyReviewStore.currentStreak()) ?? 0
        guard !educationItems.isEmpty else {
            dueItems = []
            caughtUpText = nil
            return
        }
        let ids = educationItems.map(\.id)
        let entries = (try? studyReviewStore.dueEntries(itemIds: ids)) ?? []
        if entries.isEmpty {
            dueItems = []
            if let nextDue = try? studyReviewStore.nextUpcomingDueAt(itemIds: ids) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                caughtUpText = "You're all caught up! Next review \(formatter.string(from: nextDue))."
            } else {
                caughtUpText = "You're all caught up!"
            }
        } else {
            caughtUpText = nil
            let byId = Dictionary(uniqueKeysWithValues: educationItems.map { ($0.id, $0) })
            dueItems = entries.compactMap { entry in byId[entry.itemId].map { (entry, $0) } }
        }
    }

    private func markReviewed(_ offlineItemId: String, confident: Bool) {
        try? studyReviewStore.markReviewed(offlineItemId: offlineItemId, confident: confident)
        loadReview()
    }
}

/// Real tag-assignment sheet — port of `StudyMaterialActivity.showTagDialog`'s
/// dynamic level→grade/subject-or-category fields.
private struct TagDocumentSheet: View {
    let document: StudyDocument
    let onSave: (StudyDocumentTaxonomy) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var level: StudyLevel?
    @State private var grade: String?
    @State private var subject: String?
    @State private var category: String?
    @State private var resourceType: String?
    @State private var yearText: String
    @State private var language: String?

    init(document: StudyDocument, onSave: @escaping (StudyDocumentTaxonomy) -> Void) {
        self.document = document
        self.onSave = onSave
        _level = State(initialValue: document.level)
        _grade = State(initialValue: document.grade)
        _subject = State(initialValue: document.subject)
        _category = State(initialValue: document.category)
        _resourceType = State(initialValue: document.resourceType)
        _yearText = State(initialValue: document.year.map(String.init) ?? "")
        _language = State(initialValue: document.language)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Level") {
                    Picker("Level", selection: $level) {
                        Text("Choose a level").tag(StudyLevel?.none)
                        ForEach(StudyLevel.allCases, id: \.self) { candidate in
                            Text(candidate.label).tag(Optional(candidate))
                        }
                    }
                    .accessibilityIdentifier("tagLevelPicker")
                }
                .onChange(of: level) { _ in
                    grade = nil
                    subject = nil
                    category = nil
                }

                if level == .basicEducation {
                    Section("Grade & Subject") {
                        Picker("Grade", selection: $grade) {
                            Text("Choose a grade").tag(String?.none)
                            ForEach(studyGrades, id: \.id) { gradeOption in
                                Text(gradeOption.label).tag(Optional(gradeOption.id))
                            }
                        }
                        .accessibilityIdentifier("tagGradePicker")
                        Picker("Subject", selection: $subject) {
                            Text("Choose a subject").tag(String?.none)
                            ForEach(basicEducationSubjects, id: \.self) { subjectOption in
                                Text(subjectOption).tag(Optional(subjectOption))
                            }
                        }
                        .accessibilityIdentifier("tagSubjectPicker")
                    }
                } else if let level, level == .higherEducation || level == .professional {
                    Section("Category") {
                        Picker("Category", selection: $category) {
                            Text("Choose a category").tag(String?.none)
                            ForEach(StudyTaxonomy.categories(forLevel: level), id: \.self) { categoryOption in
                                Text(categoryOption).tag(Optional(categoryOption))
                            }
                        }
                        .accessibilityIdentifier("tagCategoryPicker")
                    }
                }

                Section("Resource Type") {
                    Picker("Resource Type", selection: $resourceType) {
                        Text("Choose a type").tag(String?.none)
                        ForEach(studyResourceTypes, id: \.id) { resourceTypeOption in
                            Text(resourceTypeOption.label).tag(Optional(resourceTypeOption.id))
                        }
                    }
                    .accessibilityIdentifier("tagResourceTypePicker")
                }

                Section("Year") {
                    TextField("e.g. 2024", text: $yearText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("tagYearInput")
                }

                Section("Language") {
                    Picker("Language", selection: $language) {
                        Text("Choose a language").tag(String?.none)
                        ForEach(studyLanguages, id: \.self) { languageOption in
                            Text(languageOption).tag(Optional(languageOption))
                        }
                    }
                    .accessibilityIdentifier("tagLanguagePicker")
                }
            }
            .scrollContentBackground(.hidden)
            .visionScreen()
            .navigationTitle(document.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(StudyDocumentTaxonomy(
                            level: level,
                            grade: level == .basicEducation ? grade : nil,
                            category: (level == .higherEducation || level == .professional) ? category : nil,
                            subject: level == .basicEducation ? subject : nil,
                            resourceType: resourceType,
                            year: Int(yearText),
                            language: language
                        ))
                    }
                    .accessibilityIdentifier("btnTagSave")
                }
            }
        }
    }
}
