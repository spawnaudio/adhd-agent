import SwiftUI
import FocusFlowCore

extension AppStore {
    func sendChat() {
        guard state.agentEnabled else { settingsVisible = true; return }
        let prompt = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !chatThinking else { return }
        if state.conversation == nil { state.conversation = CompanionConversation() }
        guard let id = state.conversation?.id else { return }
        let message = CompanionMessage(role: .user, text: prompt)
        state.conversation?.messages.append(message)
        chatInput = ""
        chatError = nil
        chatThinking = true
        let port = state.agentPort
        chatTask = Task { [weak self] in
            guard let self else { return }
            defer { chatThinking = false }
            do {
                try await companionServer.ensureRunning(port: port)
                try Task.checkCancellation()
                let reply = try await CompanionClient(port: port).chat(prompt: prompt, conversationID: id)
                try Task.checkCancellation()
                guard state.conversation?.id == id else { return }
                state.conversation?.messages.append(CompanionMessage(role: .model, text: reply))
            } catch {
                if state.conversation?.id == id {
                    state.conversation?.messages.removeAll { $0.id == message.id }
                    if chatInput.isEmpty { chatInput = prompt }
                    if !Task.isCancelled { chatError = error.localizedDescription }
                }
            }
        }
    }

    func stopCompanion() {
        chatTask?.cancel()
        cancelSuggestion()
        companionServer.stop()
        connectionStatus = "Companion is disabled."
    }
}

struct CompanionChatView: View {
    @ObservedObject var store: AppStore
    @State private var confirmNewConversation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(text: "Focus & Flow · Gemini")
                Spacer()
                Button("New conversation") { confirmNewConversation = true }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(store.chatThinking || (store.state.conversation?.messages.isEmpty ?? true))
            }
            if !store.state.agentEnabled {
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your companion is here.").font(.system(size: 24, design: .serif))
                        Text("Turn on Gemini to talk through a task, find a tiny starting step, or get back on track. Your messages go to your configured Google service.")
                            .font(.system(size: 14)).foregroundStyle(Palette.muted)
                        Button("Companion settings") { store.settingsVisible = true }.buttonStyle(PrimaryButtonStyle())
                    }
                }
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if store.state.conversation?.messages.isEmpty ?? true {
                                Text("What feels difficult right now? A few words are enough.")
                                    .font(.system(size: 19, design: .serif)).foregroundStyle(Palette.muted).padding(.vertical, 24)
                            }
                            ForEach(store.state.conversation?.messages ?? []) { message in
                                Surface(color: message.role == .user ? Palette.pale : .white.opacity(0.83)) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Eyebrow(text: message.role == .user ? "You" : "Focus & Flow")
                                        Text(LocalizedStringKey(message.text)).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled)
                                    }
                                }.id(message.id)
                            }
                            if store.chatThinking { ProgressView("Thinking with you…").font(.system(size: 12)).padding() }
                        }
                    }.frame(height: 340)
                    .onChange(of: store.state.conversation?.messages.count) { _, _ in
                        if let id = store.state.conversation?.messages.last?.id { reader.scrollTo(id, anchor: .bottom) }
                    }
                }
                if let error = store.chatError {
                    Text(error).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Tell me what's on your mind…", text: $store.chatInput, axis: .vertical)
                            .lineLimit(2...5).textFieldStyle(.plain).font(.system(size: 14))
                            .accessibilityLabel("Message to companion")
                        HStack {
                            Text("Use Focus for countdowns. Your other notes and plan are not attached to chat.")
                                .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Spacer()
                            Button("Send") { store.sendChat() }.buttonStyle(PrimaryButtonStyle())
                                .keyboardShortcut(.return, modifiers: .command)
                                .disabled(store.chatThinking || store.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
        .alert("Start a new conversation?", isPresented: $confirmNewConversation) {
            Button("Cancel", role: .cancel) {}
            Button("Start new") { store.state.conversation = CompanionConversation(); store.chatError = nil }
        } message: { Text("The current conversation will leave this view. Your notes, plan, and timers stay saved.") }
    }
}
