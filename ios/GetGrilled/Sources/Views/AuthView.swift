import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .signIn

    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let user = viewModel.currentUser, !viewModel.isAnonymous {
                    signedInView(email: user.email ?? "")
                } else {
                    signedOutForm
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func signedInView(email: String) -> some View {
        VStack(spacing: 16) {
            Text("Signed in as").foregroundStyle(.secondary)
            Text(email).font(.headline)
            Button("Sign Out", role: .destructive) { viewModel.signOut() }
        }
    }

    private var signedOutForm: some View {
        VStack(spacing: 16) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            Button(mode.rawValue) {
                mode == .signIn ? viewModel.signIn() : viewModel.signUp()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email]
                request.nonce = viewModel.prepareAppleRequestNonce()
            } onCompletion: { result in
                viewModel.handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)

            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
