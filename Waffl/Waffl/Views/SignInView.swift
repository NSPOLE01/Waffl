//
//  SignInView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingCreateAccountAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                HStack {
                    Button(action: {
                        NotificationCenter.default.post(name: .dismissAuth, object: nil)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(.top, 20)
                
                // Header
                SignInHeaderView()
                
                // Form
                SignInFormView(
                    email: $email,
                    password: $password,
                    isShowingPassword: $isShowingPassword
                )
                
                // Sign In Button - Fixed: Added onSignIn parameter
                SignInButtonView(
                    email: email,
                    password: password,
                    isLoading: isLoading,
                    onSignIn: signInWithEmail
                )
                
                // Or divider
                OrDividerView()
                
                // Google Sign In Button - Fixed: Added parameters
                GoogleSignInButtonView(
                    isLoading: isLoading,
                    onGoogleSignIn: signInWithGoogle
                )
                
                Spacer()
                
                // Sign Up Link
                SignUpLinkView()
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    private func signInWithEmail() {
        isLoading = true
        errorMessage = ""
        showingError = false
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                } else {
                    // Success - dismiss auth flow
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
        
        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("No root view controller found")
            return
        }
        
        isLoading = true
        errorMessage = ""
        showingError = false
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [self] result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.errorMessage = "Failed to get Google ID token"
                    self.showingError = true
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.showingError = true
                        return
                    }
                    
                    // Check if user exists in Firestore
                    guard let firebaseUser = authResult?.user else {
                        self.errorMessage = "Authentication failed"
                        self.showingError = true
                        return
                    }
                    
                    self.checkUserExistsInFirestore(uid: firebaseUser.uid)
                }
            }
        }
    }
        
        
    private func checkUserExistsInFirestore(uid: String) {
        let db = Firestore.firestore()
        
        db.collection("users").document(uid).getDocument { [self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error checking user profile: \(error.localizedDescription)"
                    self.showingError = true
                    try? Auth.auth().signOut()
                    return
                }
                
                guard let document = document, document.exists else {
                    self.showingCreateAccountAlert = true
                    try? Auth.auth().signOut()
                    return
                }
                
                // User exists - proceed with normal sign in
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
            
            Text("Sign in to continue sharing your weekly moments")
                .font(.system(size: 16))
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.center)
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
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primary)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primary)
                
                HStack {
                    if isShowingPassword {
                        TextField("Enter your password", text: $password)
                    } else {
                        SecureField("Enter your password", text: $password)
                    }
                    
                    Button(action: {
                        isShowingPassword.toggle()
                    }) {
                        Image(systemName: isShowingPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color.secondary)
                    }
                }
                .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Forgot Password
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    // Forgot password action
                }
                .font(.system(size: 14))
                .foregroundColor(.orange)
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
            .background(Color.orange)
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
            .foregroundColor(.orange)
        }
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

struct GoogleSignInButtonView: View {
    let isLoading: Bool
    let onGoogleSignIn: () -> Void
    
    var body: some View {
        Button(action: onGoogleSignIn) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.primary)
                } else {
                    // Google "G" logo recreation using SF Symbols
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                        
                        Text("G")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Sign in with Google")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}
