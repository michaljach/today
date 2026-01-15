import ComposableArchitecture
import SwiftUI

struct EditProfileView: View {
    @Bindable var store: StoreOf<EditProfileFeature>
    @FocusState private var focusedField: Field?
    
    enum Field {
        case displayName
        case username
        case email
        case currentPassword
        case newPassword
        case confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    LabeledContent("Display Name") {
                        TextField("Display Name", text: $store.displayName)
                            .textContentType(.name)
                            .focused($focusedField, equals: .displayName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    LabeledContent("Username") {
                        HStack {
                            TextField("Username", text: $store.username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .username)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: store.username) { _, newValue in
                                    let sanitized = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    if sanitized != newValue {
                                        store.username = sanitized
                                    }
                                }
                            
                            if store.isCheckingUsername {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if store.username != store.user.username {
                                if store.usernameAvailable == true {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if store.usernameAvailable == false {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Profile")
                } footer: {
                    if store.username != store.user.username && store.usernameAvailable == false {
                        Text("This username is already taken")
                            .foregroundStyle(.red)
                    }
                }
                
                // Email Section
                Section {
                    TextField("Email", text: $store.newEmail)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .focused($focusedField, equals: .email)
                } header: {
                    Text("Email")
                } footer: {
                    if store.hasEmailChange {
                        Text("A confirmation email will be sent to verify the new address")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Password Section
                Section {
                    SecureField("New Password", text: $store.newPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .newPassword)
                    
                    SecureField("Confirm Password", text: $store.confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                } header: {
                    Text("Change Password")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if !store.newPassword.isEmpty && store.newPassword.count < 6 {
                            Text("Password must be at least 6 characters")
                                .foregroundStyle(.red)
                        }
                        if !store.confirmPassword.isEmpty && !store.passwordsMatch {
                            Text("Passwords do not match")
                                .foregroundStyle(.red)
                        }
                        if store.newPassword.isEmpty && store.confirmPassword.isEmpty {
                            Text("Leave blank to keep current password")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Error/Success Messages
                if let errorMessage = store.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                if let successMessage = store.successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(successMessage)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismiss)
                    }
                    .disabled(store.isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if store.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            store.send(.saveTapped)
                        }
                        .disabled(!store.canSave)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .interactiveDismissDisabled(store.isSaving)
        }
    }
}

#Preview {
    EditProfileView(
        store: Store(
            initialState: EditProfileFeature.State(
                user: .mock1,
                email: "john@example.com"
            )
        ) {
            EditProfileFeature()
        } withDependencies: {
            $0.profileClient = .previewValue
            $0.authClient = .previewValue
        }
    )
}
