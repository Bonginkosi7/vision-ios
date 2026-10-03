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
    @State private var bubbles: [ChatBubble] = []
    @State private var messageText = ""
    @State private var sending = false

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
        } else {
            List {
                ForEach(sessions) { session in
                    Button(action: { openSession(session.id) }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).foregroundStyle(.white).font(.system(size: 14, weight: .bold))
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("askVisionSessionRow_\(session.id)")
                    .swipeActions {
                        Button(role: .destructive) {
                            try? chatSessionStore.deleteSession(session.id)
                            loadSessions()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("btnDeleteSession_\(session.id)")
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("askVisionSessionsList")
        }
    }

    @ViewBuilder
    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bubbles) { bubble in
                        bubbleView(bubble)
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

    @ViewBuilder
    private func bubbleView(_ bubble: ChatBubble) -> some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 6) {
                Text(bubble.role == "user" ? "You" : "VISION")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(DesignSystem.textMuted2)
                Text(bubble.content).font(.system(size: 14)).foregroundStyle(.white)
                    .accessibilityIdentifier(bubble.role == "user" ? "chatUserMessage_\(bubble.id)" : "chatAssistantMessage_\(bubble.id)")
                if let category = bubble.category {
                    Text(category.label).font(.system(size: 11)).foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("chatCategory_\(bubble.id)")
                }
            }
        }
        .id(bubble.id)
    }

    @ViewBuilder
    private var askBar: some View {
        HStack(spacing: 8) {
            TextField("Ask VISION anything…", text: $messageText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                .foregroundStyle(.white)
                .accessibilityIdentifier("chatMessageInput")
            Button("Send") { send() }
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
            let assistantBubbleId = UUID().uuidString
            bubbles.append(ChatBubble(id: assistantBubbleId, role: "assistant", content: answer.text, category: answer.category))
        }
    }
}
