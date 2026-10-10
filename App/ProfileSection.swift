import SwiftUI
import PhotosUI

/// Settings → Profile: photo, name and country, like the Android app.
struct ProfileSection: View {
    @ObservedObject private var profile = ProfileStore.shared
    @AppStorage(ProfileStore.nameKey) private var name = ""
    @AppStorage(ProfileStore.countryKey) private var country = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var showResetConfirm = false

    var body: some View {
        Section {
            HStack(spacing: 16) {
                avatar
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Text(profile.photo == nil ? "Add photo" : "Change photo")
                    }
                    .accessibilityIdentifier("profilePhotoButton")
                    if profile.photo != nil {
                        Button("Remove photo") { profile.removePhoto() }
                            .accessibilityIdentifier("profileRemovePhoto")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            TextField("Your name", text: $name)
                .textContentType(.name)
                .accessibilityIdentifier("profileNameField")

            Picker("Country", selection: $country) {
                Text("Not set").tag("")
                ForEach(ProfileStore.countries, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("profileCountryPicker")

            Button("Reset profile") { showResetConfirm = true }
                .accessibilityIdentifier("profileResetButton")
        } header: {
            Text("Profile")
        } footer: {
            Text("Your name appears in the homepage greeting. Your photo, name and country stay on this phone — nothing is uploaded.")
        }
        .onChange(of: pickedItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    ProfileStore.shared.setPhoto(from: data)
                }
                pickedItem = nil
            }
        }
        .confirmationDialog("Clear your name, country and photo?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset profile") {
                profile.reset()
                name = ""
                country = ""
            }
            .accessibilityIdentifier("profileConfirmReset")
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let photo = profile.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(white: 0.22)
                    Text(ProfileStore.initials(for: name)).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
