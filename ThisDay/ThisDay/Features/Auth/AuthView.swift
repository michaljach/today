import ComposableArchitecture
import SwiftUI

struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo/Header
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.primary)
                        
                        Text("ThisDay")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(store.mode == .signIn ? "Welcome back" : "Create your account")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 16) {
                        if store.mode == .signUp {
                            TextField("Username", text: $store.username)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            
                            TextField("Display Name", text: $store.displayName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                        }
                        
                        TextField("Email", text: $store.email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $store.password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(store.mode == .signIn ? .password : .newPassword)
                        
                        if let errorMessage = store.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            store.send(.submitTapped)
                        } label: {
                            Group {
                                if store.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(store.mode == .signIn ? "Sign In" : "Sign Up")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.isFormValid || store.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    // Toggle mode
                    Button {
                        store.send(.toggleMode)
                    } label: {
                        Group {
                            if store.mode == .signIn {
                                Text("Don't have an account? ") +
                                Text("Sign Up").fontWeight(.semibold)
                            } else {
                                Text("Already have an account? ") +
                                Text("Sign In").fontWeight(.semibold)
                            }
                        }
                        .font(.subheadline)
                    }
                    .disabled(store.isLoading)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview("Sign In") {
    AuthView(
        store: Store(initialState: AuthFeature.State(mode: .signIn)) {
            AuthFeature()
        }
    )
}

#Preview("Sign Up") {
    AuthView(
        store: Store(initialState: AuthFeature.State(mode: .signUp)) {
            AuthFeature()
        }
    )
}
