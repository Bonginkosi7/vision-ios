import SwiftUI
import VisionCore

/// Settings → Privacy & data: what stays on the phone, what leaves it, and how to download or delete your data.
struct PrivacyView: View {
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var statusMessage: String?
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var showDeleted = false

    var body: some View {
        List {
            ForEach(PrivacyContent.sections, id: \.id) { section in
                Section {
                    ForEach(section.items, id: \.title) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.system(size: 15, weight: .semibold))
                            Text(item.text).font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text(section.heading)
                } footer: {
                    if let intro = section.intro { Text(intro) }
                }
            }

            Section {
                Text(PrivacyContent.Rights.exportText).font(.system(size: 14)).foregroundStyle(.secondary)
                Button(PrivacyContent.Rights.exportTitle) { export() }
                    .accessibilityIdentifier("privacyExportButton")
            } header: { Text("Download my data") }

            Section {
                Text(PrivacyContent.Rights.deleteText).font(.system(size: 14)).foregroundStyle(.secondary)
                Text(PrivacyContent.Rights.deleteLimits).font(.system(size: 13)).foregroundStyle(.secondary)
                Button(deleting ? "Deleting…" : PrivacyContent.Rights.deleteTitle, role: .destructive) { showDeleteConfirm = true }
                    .disabled(deleting)
                    .accessibilityIdentifier("privacyDeleteButton")
                    .confirmationDialog(PrivacyContent.Rights.confirmTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("Delete everything", role: .destructive) { deleteEverything() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(PrivacyContent.Rights.confirmDetail)
                    }
            } header: { Text("Delete my data") }

            Section {
                if let status = statusMessage {
                    Text(status).font(.system(size: 14)).accessibilityIdentifier("privacyStatus")
                }
                Link("Email \(PrivacyContent.contactEmail)", destination: URL(string: "mailto:\(PrivacyContent.contactEmail)")!)
                if let policy = URL(string: PrivacyContent.policyURL) { Link("Ann-Connect trust & privacy", destination: policy) }
            } header: { Text("Questions or requests") }
        }
        .navigationTitle("Privacy & data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let exportURL { ActivityView(items: [exportURL]) }
        }
        .alert("Your data was deleted", isPresented: $showDeleted) {
            Button("OK") { exit(0) }
        } message: {
            Text("VISION will now close. Open it again to start fresh.")
        }
    }

    @MainActor
    private func export() {
        do {
            exportURL = try PrivacyService.exportMyData()
            showShare = true
            statusMessage = "Your data file is ready — choose where to save or send it."
        } catch {
            statusMessage = "Your data couldn't be exported."
        }
    }

    private func deleteEverything() {
        deleting = true
        Task {
            do {
                try await PrivacyService.deleteMyData()
                showDeleted = true
            } catch {
                statusMessage = "Something went wrong while deleting. Please try again."
                deleting = false
            }
        }
    }
}

/// The system share sheet, for saving or sending the exported file.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
