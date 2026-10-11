import SwiftUI
import VisionCore

/// Settings → Saved passwords: the logins VISION can fill in from the ⋯ menu's Autofill. Same fields as
/// the Android and desktop apps (site, username, password, a generator), with the password shown or copied
/// only after Face ID / the passcode.
struct SavedPasswordsSection: View {
    @ObservedObject private var store = CredentialStore.shared

    @State private var originInput = ""
    @State private var usernameInput = ""
    @State private var passwordInput = ""
    @State private var showPassword = false
    @State private var error: String?
    @State private var revealed: [String: String] = [:]
    @State private var copiedId: String?

    var body: some View {
        Section {
            if store.credentials.isEmpty {
                Text("No saved passwords yet.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("credentialEmptyState")
            }
            ForEach(store.credentials) { credential in
                row(credential)
            }

            TextField("Website, e.g. example.com", text: $originInput)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.URL)
                .accessibilityIdentifier("credentialOriginField")
            TextField("Username or email", text: $usernameInput)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("credentialUsernameField")
            HStack {
                Group {
                    if showPassword {
                        TextField("Password", text: $passwordInput)
                    } else {
                        SecureField("Password", text: $passwordInput)
                    }
                }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("credentialPasswordField")
                Button(showPassword ? "Hide" : "Show") { showPassword.toggle() }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("credentialShowPasswordButton")
            }
            Button("Generate a strong password") {
                passwordInput = PasswordGenerator.generate()
                showPassword = true
            }
            .accessibilityIdentifier("credentialGenerateButton")

            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Color(hex: 0xE53935))
                    .accessibilityIdentifier("credentialError")
            }
            Button("Save password", action: save)
                .accessibilityIdentifier("credentialSaveButton")
        } header: {
            Text("Saved passwords")
        } footer: {
            Text("Kept in the iOS Keychain on this phone and never uploaded. Open a login page, then choose Autofill from the ⋯ menu.")
        }
    }

    @ViewBuilder
    private func row(_ credential: SavedCredential) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(credential.username).font(.system(size: 16, weight: .medium))
            Text(credential.origin).font(.system(size: 13)).foregroundStyle(.secondary)
            Text(revealed[credential.id] ?? "••••••••")
                .font(.system(size: 14, design: .monospaced)).foregroundStyle(.secondary)
                .accessibilityIdentifier("credentialPasswordText_\(credential.id)")
            HStack(spacing: 20) {
                Button(revealed[credential.id] == nil ? "Show" : "Hide") { toggleReveal(credential) }
                    .accessibilityIdentifier("credentialReveal_\(credential.id)")
                Button(copiedId == credential.id ? "Copied" : "Copy") { copy(credential) }
                    .accessibilityIdentifier("credentialCopy_\(credential.id)")
                Button("Delete", role: .destructive) {
                    revealed[credential.id] = nil
                    store.remove(id: credential.id)
                }
                .accessibilityIdentifier("credentialDelete_\(credential.id)")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 14))
        }
        .padding(.vertical, 2)
        // Keep the texts and buttons in a row as separate elements, so each stays reachable on its own.
        .accessibilityElement(children: .contain)
    }

    private func save() {
        error = nil
        let username = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let origin = AutofillLogic.normalizedOrigin(originInput), !username.isEmpty, !passwordInput.isEmpty else {
            error = "Fill in the website, the username and the password."
            return
        }
        do {
            try store.save(origin: origin, username: username, password: passwordInput)
            originInput = ""; usernameInput = ""; passwordInput = ""; showPassword = false
        } catch {
            self.error = "That password couldn't be saved."
        }
    }

    private func toggleReveal(_ credential: SavedCredential) {
        if revealed[credential.id] != nil { revealed[credential.id] = nil; return }
        Task { @MainActor in
            guard await DeviceAuth.authenticate(reason: "Show this saved password"),
                  let password = store.reveal(id: credential.id) else { return }
            revealed[credential.id] = password
        }
    }

    private func copy(_ credential: SavedCredential) {
        Task { @MainActor in
            guard await DeviceAuth.authenticate(reason: "Copy this saved password"),
                  let password = store.reveal(id: credential.id) else { return }
            // Expires from the clipboard after a minute and stays out of Universal Clipboard.
            UIPasteboard.general.setItems(
                [[UIPasteboard.typeAutomatic: password]],
                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
            )
            copiedId = credential.id
        }
    }
}
