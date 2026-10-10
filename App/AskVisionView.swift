import SwiftUI
import UniformTypeIdentifiers
import VisionCore

private enum ChatMode: Equatable {
    case sessionList
    case newChat
    case session(String)
}

private struct ChatBubble: Identifiable {
    let id: String
    let role: String
    let content: String
    let category: TaskCategory?
}

/// Real Ask VISION chat — port of the scoped-down slice of
/// ChatActivity.kt/ChatAiLogic.kt/ChatCategoryLogic.kt/
/// ChatSessionDbHelper.kt: a real, persisted, multi-session conversation
/// with a real local message-category classification (shown as a label,
/// never a claim of deep understanding), and a real honest "not
/// configured" reply when no cloud AI key is set.
///
/// Deliberately NOT ported — Android's own voice input, chat export,
/// date-grouped/searchable session history, and per-message "Remember
/// this"/"Save for offline" quick actions (each tied to Memory facts or
/// a hidden-WKWebView live-page-fetch, neither of which exist on iOS
/// yet — see README's disclosed scope trim). This is a flat, real
/// session list (newest first) and a plain conversation view — the same
/// "smallest real slice" scoping this project has used throughout.
struct AskVisionView: View {
    @ObservedObject var chatSessionStore: ChatSessionStore
    /// Real auto-submit on open — port of `ChatActivity`'s own
    /// `EXTRA_INITIAL_QUERY` handling (`startNewChat(); ask(initialQuery)`),
    /// reached from New Tab's own Ask VISION box when the typed text isn't
    /// a direct URL. `nil` for every other real entry point into this
    /// screen (the overflow menu, My Week's "Ask VISION" follow-ups, …),
    /// which still open onto the real session list exactly as before.
    var initialQuery: String? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var mode: ChatMode = .sessionList
    @State private var sessions: [ChatSessionSummary] = []
    @State private var sessionSearchText = ""
    @State private var bubbles: [ChatBubble] = []
    @State private var messageText = ""
    @StateObject private var dictation = SpeechDictation()
    @State private var attachedFile: ChatAttachment?
    @State private var attachmentError: String?
    @State private var showFileImporter = false
    /// Text typed before dictation started, so speech appends to it.
    @State private var textBeforeDictation = ""
    @State private var sending = false

    /// Port of ChatSessionListActivity.groupLabel's Today/Yesterday/Previous
    /// 7 Days/Older buckets (same Calendar-based boundaries), used to
    /// section the real session list exactly as Android does.
    private enum SessionGroup: Int, CaseIterable {
        case today, yesterday, week, older
        var label: String {
            switch self {
            case .today: return "Today"
            case .yesterday: return "Yesterday"
            case .week: return "Previous 7 Days"
            case .older: return "Older"
            }
        }
    }

    private func sessionGroup(for date: Date) -> SessionGroup {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        if date >= startOfToday { return .today }
        if date >= startOfYesterday { return .yesterday }
        if date >= sevenDaysAgo { return .week }
        return .older
    }

    private var filteredSessions: [ChatSessionSummary] {
        let query = sessionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.lowercased().contains(query) }
    }

    private var groupedSessions: [(SessionGroup, [ChatSessionSummary])] {
        let filtered = filteredSessions
        let grouped = Dictionary(grouping: filtered, by: { sessionGroup(for: $0.updatedAt) })
        return SessionGroup.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .sessionList:
                    sessionListView
                case .newChat, .session:
                    conversationView
                }
            }
            .navigationTitle(navigationTitleText)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if mode != .sessionList {
                        Button("Chats") { mode = .sessionList; loadSessions() }
                            .accessibilityIdentifier("btnBackToChats")
                    } else {
                        Button(action: startNewChat) {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityIdentifier("askVisionNewChatButton")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if mode == .sessionList {
                        Button("Done") { dismiss() }
                    } else {
                        Button(action: startNewChat) {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityIdentifier("askVisionNewChatButton")
                    }
                }
            }
            .visionScreen()
        }
        .onAppear {
            if let initialQuery, !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mode = .newChat
                bubbles = []
                messageText = initialQuery
                send()
            } else {
                loadSessions()
            }
        }
    }

    private var navigationTitleText: String {
        switch mode {
        case .sessionList: return "Ask VISION"
        case .newChat: return "New chat"
        case .session(let id): return sessions.first { $0.id == id }?.title ?? "Chat"
        }
    }

    @ViewBuilder
    private var sessionListView: some View {
        VStack(spacing: 0) {
            // Search + "New chat" row — always visible, matching
            // ChatSessionListActivity's own search row sitting above the
            // list regardless of whether it's empty.
            HStack(spacing: DesignSystem.Space.s) {
                TextField("", text: $sessionSearchText, prompt: Text("Search chats").foregroundColor(DesignSystem.textMuted2))
                    .visionField()
                    .accessibilityLabel("Search chats")
                    .accessibilityIdentifier("chatSessionSearchInput")
                DesignSystem.primaryButton("New chat", onClick: startNewChat)
                    .accessibilityIdentifier("btnNewChatFromList")
            }
            .padding(DesignSystem.Space.l)

            if sessions.isEmpty {
                DesignSystem.emptyState(
                    title: "No chats yet",
                    subtitle: "Start a real conversation with VISION.",
                    ctaText: "New chat",
                    onCta: startNewChat
                )
                .accessibilityIdentifier("askVisionEmptySessions")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredSessions.isEmpty {
                Text("No matching chats.")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("askVisionNoMatchingSessions")
            } else {
                List {
                    ForEach(groupedSessions, id: \.0) { group, items in
                        Section {
                            ForEach(items) { session in
                                sessionRow(session)
                            }
                        } header: {
                            DesignSystem.sectionLabel(group.label)
                                .textCase(nil)
                                .padding(.horizontal, DesignSystem.Space.l)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("askVisionSessionsList")
            }
        }
    }

    /// One session row — the SwiftUI counterpart of `sessionRow()` in
    /// ChatSessionListActivity: a rounded card-style background (Android's
    /// `bg_address_bar`, matched here with DesignSystem's card tokens since
    /// the real Android row is plain colorSurface + subtle stroke, not an
    /// app-specific drawable), the session title only (Android shows no
    /// per-row preview text or timestamp — date grouping is the only
    /// "timestamp" signal), and a persistent trailing delete icon button —
    /// Android never hides deletion behind a swipe gesture, so a visible
    /// button is kept here too, with `.swipeActions` layered on as a native
    /// iOS bonus rather than the only way to delete.
    @ViewBuilder
    private func sessionRow(_ session: ChatSessionSummary) -> some View {
        Button(action: { openSession(session.id) }) {
            HStack(spacing: DesignSystem.Space.m) {
                Text(session.title)
                    .font(.system(size: 15)).foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { deleteSession(session.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.textMuted2)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btnDeleteSessionRow_\(session.id)")
                .accessibilityLabel("Delete chat")
            }
            .padding(.horizontal, DesignSystem.Space.l).padding(.vertical, DesignSystem.Space.m)
            .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous).fill(DesignSystem.bgCard))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignSystem.Space.l)
        .padding(.bottom, DesignSystem.Space.s)
        .accessibilityIdentifier("askVisionSessionRow_\(session.id)")
        .swipeActions {
            Button(role: .destructive) {
                deleteSession(session.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }.tint(Color(hex: 0xE53935))
            .accessibilityIdentifier("btnDeleteSession_\(session.id)")
        }
    }

    private func deleteSession(_ id: String) {
        try? chatSessionStore.deleteSession(id)
        loadSessions()
    }

    @ViewBuilder
    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Tight spacing within an exchange, a wider gap between
                // exchanges — port of ChatActivity's single "exchange"
                // LinearLayout (user question + assistant answer stacked
                // together) with a 24dp bottomMargin between exchanges,
                // rather than one real Android screen is a flat, evenly
                // spaced bubble list.
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bubbles) { bubble in
                        bubbleView(bubble)
                            .padding(.bottom, bubble.role == "assistant" ? 20 : 0)
                    }
                }
                .padding(DesignSystem.Space.l)
            }
            .onChange(of: bubbles.count) { _ in
                if let last = bubbles.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) { askBar }
    }

    /// Port of `appendExchange`/`renderResponse` in ChatActivity.kt. Real
    /// Android behavior has NO per-message role label and NO per-message
    /// category label visible anywhere in the bubble — `TaskCategory` is
    /// only ever used internally there to decide whether to show an
    /// offline/live-source/memory action row, never rendered as text. The
    /// only real visual distinction between the two roles is: the user's
    /// question is bold text inside a rounded, bordered card
    /// (`bg_address_bar` — colorSurface fill + a subtle 1dp stroke, matched
    /// here with DesignSystem's bgCard/borderCard tokens), while VISION's
    /// answer is plain (non-bold) text with no background at all, just a
    /// small leading/top inset. Neither role uses the brand purple/gradient
    /// — Android never colors a chat bubble with vision_purple.
    @ViewBuilder
    private func bubbleView(_ bubble: ChatBubble) -> some View {
        if bubble.role == "user" {
            Text(bubble.content)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Space.l).padding(.vertical, DesignSystem.Space.m)
                .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous).fill(DesignSystem.bgRaised))
                .accessibilityIdentifier("chatUserMessage_\(bubble.id)")
                .id(bubble.id)
        } else {
            Text(bubble.content)
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Space.s).padding(.vertical, DesignSystem.Space.xs)
                .accessibilityIdentifier("chatAssistantMessage_\(bubble.id)")
                .id(bubble.id)
        }
    }

    @ViewBuilder
    private var askBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.s) {
            if dictation.isListening {
                Text(dictation.isOnDevice ? "Listening… (on this phone)" : "Listening… (Apple processes the audio)")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("chatListeningLabel")
            }
            if let error = dictation.errorMessage {
                Text(error).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("chatDictationError")
            }
            if let attachment = attachedFile {
                HStack(spacing: DesignSystem.Space.s) {
                    Image(systemName: "doc.text").accessibilityHidden(true)
                    Text(attachment.name).font(.system(size: 14)).lineLimit(1)
                    Spacer(minLength: 0)
                    Button(action: { attachedFile = nil }) {
                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Remove attachment")
                    .accessibilityIdentifier("chatRemoveAttachment")
                }
                .foregroundStyle(.white)
                .padding(.leading, DesignSystem.Space.m)
                .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("chatAttachmentChip")
            }
            if let attachError = attachmentError {
                Text(attachError).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("chatAttachmentError")
            }
            HStack(spacing: DesignSystem.Space.xs) {
                Button(action: { showFileImporter = true }) {
                    Image(systemName: "paperclip").font(.system(size: 18)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .disabled(sending)
                .accessibilityLabel("Attach a file")
                .accessibilityIdentifier("chatAttachButton")

                TextField("", text: $messageText, prompt: Text(attachedFile == nil ? "Ask VISION anything…" : "Ask about this file…").foregroundColor(DesignSystem.textMuted2))
                    .textFieldStyle(.plain)
                    .disabled(sending)
                    .padding(.horizontal, DesignSystem.Space.m).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Ask VISION")
                    .accessibilityIdentifier("chatMessageInput")

                Button(action: toggleDictation) {
                    Image(systemName: dictation.isListening ? "stop.circle.fill" : "mic").font(.system(size: 20)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .disabled(sending)
                .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Dictate")
                .accessibilityIdentifier("chatMicButton")

                DesignSystem.primaryButton("Send", onClick: send)
                    .opacity(sending ? 0.5 : 1)
                    .disabled(sending)
                    .accessibilityIdentifier("btnChatSend")
            }
        }
        .padding(DesignSystem.Space.l)
        .background(DesignSystem.bgCanvas)
        .onChange(of: dictation.transcript) { transcript in
            guard dictation.isListening || !transcript.isEmpty else { return }
            let prefix = textBeforeDictation.isEmpty ? "" : textBeforeDictation + " "
            messageText = prefix + transcript
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: Self.attachableTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
    }

    private static let attachableTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText]
        if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
        return types
    }()

    private func toggleDictation() {
        if !dictation.isListening { textBeforeDictation = messageText }
        dictation.toggle()
    }

    private func handleFilePick(_ result: Result<[URL], Error>) {
        attachmentError = nil
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try AttachmentReader.text(from: url)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                attachmentError = "That file has no readable text (a scanned PDF or an image can't be read)."
                return
            }
            attachedFile = ChatAttachment(name: url.lastPathComponent, text: text)
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func loadSessions() {
        sessions = (try? chatSessionStore.listSessions()) ?? []
    }

    private func startNewChat() {
        mode = .newChat
        bubbles = []
    }

    private func openSession(_ sessionId: String) {
        mode = .session(sessionId)
        let messages = (try? chatSessionStore.messagesForSession(sessionId)) ?? []
        bubbles = messages.map { ChatBubble(id: $0.id, role: $0.role, content: $0.content, category: $0.category.flatMap { TaskCategory(rawValue: $0) }) }
    }

    private func send() {
        if dictation.isListening { dictation.stop() }
        let typed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = attachedFile
        guard !typed.isEmpty || attachment != nil else { return }
        let message = typed.isEmpty ? "Summarize this file." : typed
        // What the conversation shows and saves: the question, tagged with
        // the file's name. The file's text is only sent for this one answer.
        let shownMessage = attachment.map { "📎 \($0.name)\n\(message)" } ?? message
        messageText = ""
        attachedFile = nil
        attachmentError = nil

        let userBubbleId = UUID().uuidString
        bubbles.append(ChatBubble(id: userBubbleId, role: "user", content: shownMessage, category: nil))
        // Real interim placeholder — port of appendExchange's `chat_asking`
        // ("Asking VISION…") text, shown in the assistant slot until the
        // real response replaces it, exactly like Android's `aiText`.
        let pendingBubbleId = UUID().uuidString
        bubbles.append(ChatBubble(id: pendingBubbleId, role: "assistant", content: "Asking VISION…", category: nil))
        sending = true

        let existingSessionId: String? = {
            if case .session(let id) = mode { return id }
            return nil
        }()

        Task {
            let priorMessages = existingSessionId.flatMap { try? chatSessionStore.messagesForSession($0) } ?? []
            let history = priorMessages.map { ChatMessage(role: $0.role, content: $0.content) }
            let answer = await ChatAI.ask(message: message, history: history, attachment: attachment)

            let sessionId: String
            if let existingSessionId {
                sessionId = existingSessionId
            } else {
                let created = (try? chatSessionStore.createSession(title: ChatSessionTitle.derive(fromFirstMessage: message)))
                    ?? ChatSessionSummary(id: UUID().uuidString, title: ChatSessionTitle.derive(fromFirstMessage: message), createdAt: Date(), updatedAt: Date())
                sessionId = created.id
                mode = .session(sessionId)
            }

            try? chatSessionStore.addMessage(sessionId: sessionId, role: "user", content: shownMessage, category: answer.category.rawValue, providerName: nil)
            try? chatSessionStore.addMessage(sessionId: sessionId, role: "assistant", content: answer.text, category: answer.category.rawValue, providerName: answer.providerName)
            try? chatSessionStore.touchSession(sessionId)

            sending = false
            if let pendingIndex = bubbles.firstIndex(where: { $0.id == pendingBubbleId }) {
                bubbles[pendingIndex] = ChatBubble(id: pendingBubbleId, role: "assistant", content: answer.text, category: answer.category)
            } else {
                bubbles.append(ChatBubble(id: UUID().uuidString, role: "assistant", content: answer.text, category: answer.category))
            }
        }
    }
}
