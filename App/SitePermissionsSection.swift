import SwiftUI
import VisionCore

/// Settings → Site permissions: every remembered camera/microphone answer, with a way to take each one back.
struct SitePermissionsSection: View {
    @ObservedObject private var store = SitePermissionStore.shared

    var body: some View {
        Section {
            NavigationLink {
                SitePermissionsList(store: store)
            } label: {
                HStack {
                    Text("Site permissions")
                    Spacer()
                    Text(store.permissions.isEmpty ? "None" : "\(store.permissions.count)")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("sitePermissionsLink")
        } footer: {
            Text("Sites you've allowed or blocked from using your camera or microphone.")
        }
    }
}

private struct SitePermissionsList: View {
    @ObservedObject var store: SitePermissionStore
    @State private var confirmReset = false

    var body: some View {
        List {
            if store.permissions.isEmpty {
                Text("No sites yet. When a page asks to use your camera or microphone and you choose, it shows up here.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("sitePermissionsEmpty")
            }
            ForEach(store.permissions) { permission in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(permission.origin.replacingOccurrences(of: "https://", with: ""))
                            .font(.system(size: 15, weight: .medium)).lineLimit(1)
                        Text(permission.kind?.label.capitalized ?? permission.permission)
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(permission.granted ? "Allowed" : "Blocked")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(permission.granted ? Color.green : Color.red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("sitePermissionRow_\(permission.id)")
                .swipeActions {
                    Button(role: .destructive) { store.remove(permission) } label: { Label("Remove", systemImage: "trash") }
                        .accessibilityIdentifier("sitePermissionRemove_\(permission.id)")
                }
            }
            if !store.permissions.isEmpty {
                Button("Reset all site permissions", role: .destructive) { confirmReset = true }
                    .accessibilityIdentifier("sitePermissionsResetAll")
            }
        }
        .navigationTitle("Site permissions")
        .confirmationDialog("Forget every site's answer?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset all", role: .destructive) { store.removeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sites will ask again the next time they want your camera or microphone.")
        }
        .onAppear { store.reload() }
    }
}
