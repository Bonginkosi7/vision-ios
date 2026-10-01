import SwiftUI
import UniformTypeIdentifiers
import VisionCore

struct TopicsUIState {
    var expanded = false
    var loading = false
    var topics: [Topic]?
    var error: String?
}

/// Real "My Materials" screen — port of MaterialsActivity.kt/
/// MaterialsAdapter.kt: upload a real document, extract its real text,
/// then optionally run one real AI call to identify its real topics —
/// the exact "Study Materials & Documents...unlocks Flashcards/Exams/
/// Tutor via topic extraction" slice from the build plan.
///
/// Android's separate, later-added "Study Material hub"
/// (StudyMaterialActivity.kt — taxonomy tagging, browse/search,
/// offline-ready marking, folded-in spaced-repetition review) is a real,
/// distinct feature this phase deliberately does NOT port — see
/// README's disclosed scope trim.
struct MaterialsView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var topicStore: TopicStore
    @Environment(\.dismiss) private var dismiss

    @State private var documents: [StudyDocument] = []
    @State private var topicsState: [String: TopicsUIState] = [:]
    @State private var uploadStatus: String?
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "📚",
                        title: "No materials yet",
                        subtitle: "Upload a PDF, DOCX, or TXT file to get started.",
                        ctaText: "Add material",
                        onCta: { showFilePicker = true }
                    )
                    .accessibilityIdentifier("emptyMaterialsState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    List {
                        if let uploadStatus {
                            Text(uploadStatus)
                                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                                .accessibilityIdentifier("materialsUploadStatus")
                        }
                        ForEach(documents) { doc in
                            documentRow(doc)
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("materialsList")
                }
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("My Materials")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("btnAddMaterial")
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, UTType(filenameExtension: "docx") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handlePicked(result)
            }
        }
        .onAppear { refresh() }
    }

    @ViewBuilder
    private func documentRow(_ doc: StudyDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.title).foregroundStyle(.white).font(.system(size: 14, weight: .bold))
                .accessibilityIdentifier("materialTitle_\(doc.id)")
            Text("\(statusLabel(doc.status)) · \(doc.fileType.label) · \(ByteCountFormatter.string(fromByteCount: doc.sizeBytes, countStyle: .file))")
                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("materialStatus_\(doc.id)")

            if doc.status == .failed, let error = doc.processingError {
                Text(error).font(.system(size: 12)).foregroundStyle(DesignSystem.statusDangerText)
            }

            HStack(spacing: 12) {
                if doc.status == .uploaded || doc.status == .failed {
                    Button(doc.status == .failed ? "Retry" : "Process") { process(doc) }
                        .font(.system(size: 12, weight: .bold))
                        .accessibilityIdentifier("btnProcessDocument_\(doc.id)")
                }
                if doc.status == .processed {
                    topicsButton(doc)
                }
                Spacer()
                Button(action: { delete(doc) }) {
                    Image(systemName: "trash").foregroundStyle(DesignSystem.textMuted2)
                }
                .accessibilityIdentifier("btnDeleteDocument_\(doc.id)")
            }

            topicsSection(doc)
        }
        .padding(.vertical, 8)
        // Deliberately NO .accessibilityIdentifier on this whole VStack:
        // a real captured .xcresult accessibility-tree dump (this
        // project's established forensics technique) showed that when an
        // ancestor container like this one carries its own identifier,
        // SwiftUI doesn't just leak it onto plain StaticText leaves (the
        // Phase 6/7 quirk) — it can overwrite a CHILD BUTTON'S OWN
        // explicit .accessibilityIdentifier too, exactly what broke
        // btnProcessDocument_*/btnDeleteDocument_* here (both reported
        // back with this container's identifier instead of their own).
        // Each real interactive/readable element below carries its own
        // distinct identifier instead, with nothing set at this level to
        // collide with them.
    }

    @ViewBuilder
    private func topicsButton(_ doc: StudyDocument) -> some View {
        let state = topicsState[doc.id] ?? TopicsUIState()
        Button(state.expanded ? "Hide topics" : "Topics") { toggleTopics(doc) }
            .font(.system(size: 12, weight: .bold))
            .disabled(state.loading)
            .accessibilityIdentifier("btnTopics_\(doc.id)")
    }

    @ViewBuilder
    private func topicsSection(_ doc: StudyDocument) -> some View {
        let state = topicsState[doc.id] ?? TopicsUIState()
        if state.loading {
            Text("Identifying topics…")
                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("topicsStatus_\(doc.id)")
        } else if let error = state.error {
            Text(error)
                .font(.system(size: 12)).foregroundStyle(DesignSystem.statusDangerText)
                .accessibilityIdentifier("topicsStatus_\(doc.id)")
        } else if state.expanded, let topics = state.topics {
            let topLevel = topics.filter { $0.level == 1 }
            if topLevel.isEmpty {
                Text("No real topics were found in this document.")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("topicsEmpty_\(doc.id)")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(topLevel) { topic in
                        let subtopics = topics.filter { $0.parentTopicId == topic.id }
                        Text(topic.name).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        if !subtopics.isEmpty {
                            Text(subtopics.map(\.name).joined(separator: " · "))
                                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                        }
                    }
                }
                .padding(.top, 4)
                .accessibilityIdentifier("topicsContainer_\(doc.id)")
            }
        }
    }

    private func statusLabel(_ status: StudyDocumentStatus) -> String {
        switch status {
        case .uploaded: return "Uploaded"
        case .processing: return "Processing"
        case .processed: return "Processed"
        case .failed: return "Failed"
        }
    }

    private func refresh() {
        documents = (try? studyDocumentStore.list()) ?? []
    }

    private func handlePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            uploadStatus = "Uploading…"
            do {
                _ = try DocumentImport.importFile(at: url, store: studyDocumentStore)
                uploadStatus = "Uploaded"
            } catch {
                uploadStatus = error.localizedDescription
            }
            refresh()
        case .failure(let error):
            uploadStatus = error.localizedDescription
        }
    }

    private func process(_ doc: StudyDocument) {
        // Deferred to the next run loop turn rather than mutated
        // synchronously here: this is called from the "Process"/"Retry"
        // button's OWN action closure, and that button only renders
        // while doc.status is .uploaded/.failed (see documentRow) — so
        // setStatus(.processing) immediately removes THIS SAME button
        // from the view hierarchy while its own tap gesture is still
        // being finalized. The Delete button (the only other real
        // sibling in that HStack) then shifts into the vacated screen
        // position in time to catch a follow-up touch meant for the
        // just-removed Process button. Confirmed for real via
        // .xcresult forensics: the seeded fixture's real DB row AND its
        // real file on disk were BOTH genuinely deleted moments after
        // "Process" was tapped, tracing straight to delete(doc) firing
        // unexpectedly. Deferring one run loop turn lets this tap fully
        // resolve before the layout changes.
        DispatchQueue.main.async {
            setStatus(doc.id, .processing)
            let store = studyDocumentStore
            // `studyDocumentStore` is a MainActor-isolated SwiftUI
            // property; capturing it into a plain local before entering
            // Task.detached's non-isolated closure avoids an actor-
            // isolation violation (a real Swift 6 concurrency-checker
            // warning caught this) while still running the real file
            // I/O off the main thread, matching MaterialsActivity.kt's
            // own Thread{}.start() + mainHandler.post{} pattern.
            Task.detached {
                DocumentImport.process(documentId: doc.id, store: store)
                await MainActor.run { refresh() }
            }
        }
    }

    private func setStatus(_ id: String, _ status: StudyDocumentStatus) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].status = status
    }

    /// Tap-to-reveal — direct port of MaterialsActivity.kt's
    /// toggleTopics(): the first tap either shows already-extracted
    /// topics (real rows already in TopicStore) or runs one real AI
    /// extraction call if none exist yet; a second tap just collapses the
    /// real cached result rather than re-extracting.
    private func toggleTopics(_ doc: StudyDocument) {
        var state = topicsState[doc.id] ?? TopicsUIState()
        if state.expanded {
            state.expanded = false
            topicsState[doc.id] = state
            return
        }
        if state.topics != nil {
            state.expanded = true
            topicsState[doc.id] = state
            return
        }
        if let existing = try? topicStore.listForDocument(doc.id), !existing.isEmpty {
            topicsState[doc.id] = TopicsUIState(expanded: true, loading: false, topics: existing, error: nil)
            return
        }

        topicsState[doc.id] = TopicsUIState(loading: true)
        Task {
            let result = await TopicExtractor.extract(documentText: doc.extractedText ?? "")
            guard result.ok, let data = result.data else {
                topicsState[doc.id] = TopicsUIState(error: result.error ?? "Couldn't identify topics for this document.")
                return
            }
            let saved = (try? topicStore.replaceForDocument(documentId: doc.id, topics: data)) ?? []
            topicsState[doc.id] = TopicsUIState(expanded: true, loading: false, topics: saved, error: nil)
        }
    }

    private func delete(_ doc: StudyDocument) {
        DocumentImport.remove(documentId: doc.id, store: studyDocumentStore)
        topicsState.removeValue(forKey: doc.id)
        refresh()
    }
}
