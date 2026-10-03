import SwiftUI
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
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
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
            HStack(spacing: 8) {
                TextField("Search chats", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("chatSessionSearchInput")
                DesignSystem.primaryButton("New chat", onClick: startNewChat)
                    .accessibilityIdentifier("btnNewChatFromList")
            }
            .padding(16)

            if sessions.isEmpty {
                DesignSystem.emptyState(
                    emoji: "💬",
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
                            Text(group.label)
                                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                                .textCase(nil)
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
            HStack(spacing: 12) {
                Text(session.title)
                    .font(.system(size: 14)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { deleteSession(session.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.textMuted2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btnDeleteSessionRow_\(session.id)")
                .accessibilityLabel("Delete chat")
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(DesignSystem.bgCard))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.borderCard, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .accessibilityIdentifier("askVisionSessionRow_\(session.id)")
        .swipeActions {
            Button(role: .destructive) {
                deleteSession(session.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
                .padding(16)
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
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(DesignSystem.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.borderCard, lineWidth: 1))
                .accessibilityIdentifier("chatUserMessage_\(bubble.id)")
                .id(bubble.id)
        } else {
            Text(bubble.content)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .accessibilityIdentifier("chatAssistantMessage_\(bubble.id)")
                .id(bubble.id)
        }
    }

    @ViewBuilder
    private var askBar: some View {
        HStack(spacing: 8) {
            TextField("Ask VISION anything…", text: $messageText)
                .textFieldStyle(.plain)
                .disabled(sending)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                .foregroundStyle(.white)
                .accessibilityIdentifier("chatMessageInput")
            DesignSystem.primaryButton("Send", onClick: send)
                .opacity(sending ? 0.5 : 1)
                .disabled(sending)
                .accessibilityIdentifier("btnChatSend")
        }
        .padding(16)
        .background(DesignSystem.bgCanvas)
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
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        messageText = ""

        let userBubbleId = UUID().uuidString
        bubbles.append(ChatBubble(id: userBubbleId, role: "user", content: message, category: nil))
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
            let answer = await ChatAI.ask(message: message, history: history)

            let sessionId: String
            if let existingSessionId {
                sessionId = existingSessionId
            } else {
                let created = (try? chatSessionStore.createSession(title: ChatSessionTitle.derive(fromFirstMessage: message)))
                    ?? ChatSessionSummary(id: UUID().uuidString, title: ChatSessionTitle.derive(fromFirstMessage: message), createdAt: Date(), updatedAt: Date())
                sessionId = created.id
                mode = .session(sessionId)
            }

            try? chatSessionStore.addMessage(sessionId: sessionId, role: "user", content: message, category: answer.category.rawValue, providerName: nil)
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
