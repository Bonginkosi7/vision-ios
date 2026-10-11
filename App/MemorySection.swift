import SwiftUI

/// Settings → VISION Memory: facts you tell VISION to remember. Only what you type here — VISION never
/// writes one itself. Ask VISION reads them so its answers can be personal.
struct MemorySection: View {
    @ObservedObject private var store = MemoryStore.shared
    @State private var input = ""
    @State private var confirmClear = false

    var body: some View {
        Section {
            if store.entries.isEmpty {
                Text("Nothing remembered yet.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("memoryEmptyState")
            }
            ForEach(store.entries) { entry in
                HStack(alignment: .top) {
                    Text(entry.text).font(.system(size: 15))
                    Spacer(minLength: 8)
                    Button("Remove", role: .destructive) { store.remove(id: entry.id) }
                        .buttonStyle(.borderless).font(.system(size: 14))
                        .accessibilityIdentifier("memoryRemove_\(entry.id)")
                }
            }
            TextField("e.g. I'm a Grade 11 student in Cape Town", text: $input, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityIdentifier("memoryInput")
            Button("Add") {
                store.add(input)
                input = ""
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("memoryAddButton")
            if !store.entries.isEmpty {
                Button("Clear all", role: .destructive) { confirmClear = true }
                    .accessibilityIdentifier("memoryClearAllButton")
                    .confirmationDialog("Remove everything VISION remembers about you? This can't be undone.", isPresented: $confirmClear, titleVisibility: .visible) {
                        Button("Clear all", role: .destructive) { store.clearAll() }
                        Button("Cancel", role: .cancel) {}
                    }
            }
        } header: {
            Text("VISION Memory")
        } footer: {
            Text("Facts you choose to share with VISION. They stay on this phone and are included when you ask VISION a question, so answers can be personal. VISION never adds one by itself.")
        }
    }
}
