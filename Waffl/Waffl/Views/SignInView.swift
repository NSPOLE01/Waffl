//
//  SignInView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit



struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var isLoading = false
    @State private var showingCreateAccountAlert = false
    @State private var showingSignInError = false
    @State private var signInErrorMessage = ""
    @StateObject private var appleSignInCoordinator = AppleSignInCoordinator()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                HStack {
                    Button(action: {
                        NotificationCenter.default.post(name: .dismissAuth, object: nil)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                }
                .padding(.top, 20)
                
                SignInHeaderView()
                
                SignInFormView(
                    email: $email,
                    password: $password,
                    isShowingPassword: $isShowingPassword
                )
                
                SignInButtonView(
                    email: email,
                    password: password,
                    isLoading: isLoading,
                    onSignIn: signInWithEmail
                )
                
                OrDividerView()

                HStack(spacing: 16) {
                    // Google Sign In Button
                    GoogleCircularButton(
                        isLoading: isLoading,
                        action: signInWithGoogle
                    )

                    // Apple Sign In Button
                    AppleCircularButton(
                        isLoading: appleSignInCoordinator.isLoading,
                        action: {
                            appleSignInCoordinator.signInWithApple(isSignUp: false)
                        }
                    )
                }

                Spacer()
                
                SignUpLinkView()
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateAccountAlert) {
                CreateAccountPromptView {
                    showingCreateAccountAlert = false
                    NotificationCenter.default.post(name: .navigateToSignUp, object: nil)
                } onCancel: {
                    showingCreateAccountAlert = false
                }
            }
            .alert("Sign In Error", isPresented: $showingSignInError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(signInErrorMessage)
            }
            .alert("Apple Sign In Error", isPresented: $appleSignInCoordinator.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appleSignInCoordinator.errorMessage)
            }
            .sheet(isPresented: $appleSignInCoordinator.showingCreateAccountAlert) {
                CreateAccountPromptView {
                    appleSignInCoordinator.showingCreateAccountAlert = false
                    NotificationCenter.default.post(name: .navigateToSignUp, object: nil)
                } onCancel: {
                    appleSignInCoordinator.showingCreateAccountAlert = false
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    private func signInWithEmail() {
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("❌ Email sign-in error: \(error.localizedDescription)")
                    
                    // Set the error message based on the error type
                    if let authError = error as NSError?, authError.code == AuthErrorCode.wrongPassword.rawValue || authError.code == AuthErrorCode.userNotFound.rawValue {
                        signInErrorMessage = "Invalid email or password. Please check your credentials and try again."
                    } else {
                        signInErrorMessage = "Invalid email or password. Please check your credentials and try again."
                    }
                    
                    showingSignInError = true
                } else {
                    NotificationCenter.default.post(name: .dismissAuth, object: nil)
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("No Firebase client ID found")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("No root view controller found")
            return
        }
        
        isLoading = true
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Google sign-in error: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                
                guard let user = result?.user,
                      let email = user.profile?.email else {
                    print("❌ Failed to get Google user info")
                    self.isLoading = false
                    return
                }
                
                print("📧 Google user email: \(email)")
                
                self.checkUserExistsByEmail(email: email, googleUser: user)
            }
        }
    }
        
        
    private func checkUserExistsByEmail(email: String, googleUser: GIDGoogleUser) {
        let db = Firestore.firestore()
        
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [self] querySnapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                        self.showingCreateAccountAlert = true
                        return
                    }
                                        
                    self.authenticateWithFirebase(googleUser: googleUser)
                }
            }
    }
    
    private func authenticateWithFirebase(googleUser: GIDGoogleUser) {
        guard let idToken = googleUser.idToken?.tokenString else {
            return
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )
        
        Auth.auth().signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    return
                }

                NotificationCenter.default.post(name: .dismissAuth, object: nil)
            }
        }
    }

}
    
    

struct SignInHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Welcome Back")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.primary)
        }
        .padding(.top, 20)
    }
}

struct SignInFormView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isShowingPassword: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primary)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primary)

                ZStack(alignment: .trailing) {
                    if isShowingPassword {
                        TextField("Enter your password", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                    } else {
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    Button(action: {
                        isShowingPassword.toggle()
                    }) {
                        Image(systemName: isShowingPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color.secondary)
                            .font(.system(size: 16))
                    }
                    .padding(.trailing, 12)
                }
            }
            
            HStack {
                Spacer()
                Button("Forgot Password?") {
                }
                .font(.system(size: 14))
                .foregroundColor(.purple)
            }
        }
    }
}

struct SignInButtonView: View {
    let email: String
    let password: String
    let isLoading: Bool
    let onSignIn: () -> Void
    
    var body: some View {
        Button(action: onSignIn) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Text("Sign In")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.purple)
            .cornerRadius(12)
        }
        .disabled(email.isEmpty || password.isEmpty || isLoading)
        .opacity(email.isEmpty || password.isEmpty || isLoading ? 0.6 : 1.0)
    }
}

struct SignUpLinkView: View {
    var body: some View {
        HStack {
            Text("Don't have an account?")
                .font(.system(size: 16))
                .foregroundColor(Color.secondary)
            
            Button("Sign Up") {
                NotificationCenter.default.post(name: .navigateToSignUp, object: nil)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.purple)
        }
    }
}

enum GoogleButtonType {
    case signIn
    case signUp
    
    var imageName: String {
        switch self {
        case .signIn:
            return "GoogleSignInButton"
        case .signUp:
            return "GoogleSignUpButton"
        }
    }
}

struct GooglePrebuiltButton: View {
    let buttonType: GoogleButtonType
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    // Show a loading overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .cornerRadius(8)

                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(colorScheme == .dark ? "ios_dark_sq_SU" : "ios_light_sq_SU")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 54)
                }
            }
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
    }
}

struct OrDividerView: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text("or")
                .font(.system(size: 14))
                .foregroundColor(Color.secondary)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}

struct CreateAccountPromptView: View {
    let onCreateAccount: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            VStack(spacing: 12) {
                Text("Account Not Found")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We couldn't find an account associated with this Google account. Would you like to create a new account?")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    NotificationCenter.default.post(name: .navigateToSignUp, object: nil)
                }) {
                    Text("Create Account")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                
                Button(action: onCancel) {
                    HStack {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
