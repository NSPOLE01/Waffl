//
//  SignUpView.swift
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

struct SignUpView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isShowingPassword = false
    @State private var isShowingConfirmPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @StateObject private var appleSignInCoordinator = AppleSignInCoordinator()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with Back Button
                    HStack {
                        Button(action: {
                            NotificationCenter.default.post(name: .dismissAuth, object: nil)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.purple)
                        }

                        Spacer()

                        Text("Create Account")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.primary)

                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    // Form
                    SignUpFormView(
                        firstName: $firstName,
                        lastName: $lastName,
                        email: $email,
                        password: $password,
                        confirmPassword: $confirmPassword,
                        isShowingPassword: $isShowingPassword,
                        isShowingConfirmPassword: $isShowingConfirmPassword
                    )
                    
                    // Sign Up Button
                    SignUpButtonView(
                        firstName: firstName,
                        lastName: lastName,
                        email: email,
                        password: password,
                        confirmPassword: confirmPassword,
                        isLoading: isLoading,
                        onSignUp: createAccount
                    )
                    
                    OrDividerView()
                    
                    GooglePrebuiltButton(
                        buttonType: .signUp,
                        isLoading: isLoading,
                        action: signUpWithGoogle
                    )

                    AppleSignInButton(
                        buttonType: .signUp,
                        isLoading: appleSignInCoordinator.isLoading,
                        action: {
                            appleSignInCoordinator.signInWithApple(isSignUp: true)
                        }
                    )

                    Spacer(minLength: 10)
                    
                    // Sign In Link
                    SignInLinkView()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Apple Sign In Error", isPresented: $appleSignInCoordinator.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appleSignInCoordinator.errorMessage)
            }
        }
    }
    
    // MARK: - Account Creation
    private func createAccount() {
        isLoading = true
        errorMessage = ""
        showingError = false
        
        // Create user with email and password
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
                return
            }
            
            // If user creation successful, save additional user data to Firestore
            guard let user = authResult?.user else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to create user account"
                    self.showingError = true
                }
                return
            }
            
            // Save user profile data to Firestore
            self.saveUserProfile(uid: user.uid)
        }
    }
    
    private func saveUserProfile(uid: String) {
        let db = Firestore.firestore()
        
        let userData: [String: Any] = [
            "uid": uid,
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "displayName": "\(firstName) \(lastName)",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "videosUploaded": 0,
            "friendsCount": 0,
            "weeksParticipated": 0,
            "profileImageURL": "" // Empty for now, can be updated later
        ]
        
        db.collection("users").document(uid).setData(userData) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Account created but failed to save profile: \(error.localizedDescription)"
                    self.showingError = true
                } else {
                    // Success - dismiss auth flow
                    NotificationCenter.default.post(name: .dismissAuth, object: nil)
                }
            }
        }
    }
    
    // MARK: - Google Sign Up
    private func signUpWithGoogle() {
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
                    print("❌ Google sign-up error: \(error.localizedDescription)")
                    self.isLoading = false
                    self.errorMessage = "Failed to sign up with Google. Please try again."
                    self.showingError = true
                    return
                }
                
                guard let user = result?.user,
                      let googleEmail = user.profile?.email,
                      let googleGivenName = user.profile?.givenName,
                      let googleFamilyName = user.profile?.familyName else {
                    print("❌ Failed to get Google user info")
                    self.isLoading = false
                    self.errorMessage = "Failed to get user information from Google."
                    self.showingError = true
                    return
                }
                
                print("📧 Google user email: \(googleEmail)")
                print("👤 Google user name: \(googleGivenName) \(googleFamilyName)")
                
                let profileImageURL = user.profile?.imageURL(withDimension: 400)?.absoluteString ?? ""
                
                self.createFirebaseAccountWithGoogle(
                    googleUser: user,
                    email: googleEmail,
                    firstName: googleGivenName,
                    lastName: googleFamilyName,
                    profileImageURL: profileImageURL
                )
            }
        }
    }
    
    private func createFirebaseAccountWithGoogle(googleUser: GIDGoogleUser, email: String, firstName: String, lastName: String, profileImageURL: String) {
        guard let idToken = googleUser.idToken?.tokenString else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to get authentication token from Google."
                self.showingError = true
            }
            return
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )
        
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to create account: \(error.localizedDescription)"
                    self.showingError = true
                }
                return
            }
            
            guard let user = authResult?.user else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to create user account"
                    self.showingError = true
                }
                return
            }
            
            // Save user profile data to Firestore using Google info
            self.saveGoogleUserProfile(uid: user.uid, email: email, firstName: firstName, lastName: lastName, profileImageURL: profileImageURL)
        }
    }
    
    private func saveGoogleUserProfile(uid: String, email: String, firstName: String, lastName: String, profileImageURL: String) {
        let db = Firestore.firestore()
        
        let userData: [String: Any] = [
            "uid": uid,
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "displayName": "\(firstName) \(lastName)",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "videosUploaded": 0,
            "friendsCount": 0,
            "weeksParticipated": 0,
            "profileImageURL": profileImageURL
        ]
        
        db.collection("users").document(uid).setData(userData) { error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Account created but failed to save profile: \(error.localizedDescription)"
                    self.showingError = true
                } else {
                    // Success - dismiss auth flow
                    NotificationCenter.default.post(name: .dismissAuth, object: nil)
                }
            }
        }
    }

}


struct SignUpFormView: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var isShowingPassword: Bool
    @Binding var isShowingConfirmPassword: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Name Fields
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("First Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary)
                    
                    TextField("John", text: $firstName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary)
                    
                    TextField("Doe", text: $lastName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.words)
                }
            }
            
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
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primary)

                ZStack(alignment: .trailing) {
                    if isShowingConfirmPassword {
                        TextField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                    } else {
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                    }

                    Button(action: {
                        isShowingConfirmPassword.toggle()
                    }) {
                        Image(systemName: isShowingConfirmPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color.secondary)
                            .font(.system(size: 16))
                    }
                    .padding(.trailing, 12)
                }
            }
            
            // Password Requirements
            PasswordRequirementsView(password: password)
            
            // Password Match Validation
            if !confirmPassword.isEmpty {
                HStack {
                    Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(password == confirmPassword ? .green : .red)
                        .font(.system(size: 12))
                    
                    Text("Passwords match")
                        .font(.system(size: 12))
                        .foregroundColor(password == confirmPassword ? .green : .red)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct PasswordRequirementsView: View {
    let password: String
    
    private var hasMinLength: Bool {
        password.count >= 8
    }
    
    private var hasUppercase: Bool {
        password.range(of: "[A-Z]", options: .regularExpression) != nil
    }
    
    private var hasLowercase: Bool {
        password.range(of: "[a-z]", options: .regularExpression) != nil
    }
    
    private var hasNumber: Bool {
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Password must contain:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.primary)
            
            RequirementRow(text: "At least 8 characters", isValid: hasMinLength)
            RequirementRow(text: "One uppercase letter", isValid: hasUppercase)
            RequirementRow(text: "One lowercase letter", isValid: hasLowercase)
            RequirementRow(text: "One number", isValid: hasNumber)
        }
        .padding(.horizontal, 4)
    }
}

struct RequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : Color.secondary)
                .font(.system(size: 12))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(isValid ? .green : Color.secondary)
            
            Spacer()
        }
    }
}

struct SignUpButtonView: View {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
    let confirmPassword: String
    let isLoading: Bool
    let onSignUp: () -> Void
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var body: some View {
        Button(action: onSignUp) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Text("Create Account")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.purple)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isLoading)
        .opacity(isFormValid && !isLoading ? 1.0 : 0.6)
    }
}

struct AppleSignInButton: View {
    let buttonType: AppleButtonType
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    // Show a loading overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .cornerRadius(12)

                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)

                        Text(buttonType == .signUp ? "Sign up with Apple" : "Sign in with Apple")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black)
                    .cornerRadius(12)
                }
            }
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
    }
}

enum AppleButtonType {
    case signUp
    case signIn
}

struct SignInLinkView: View {
    var body: some View {
        HStack {
            Text("Already have an account?")
                .font(.system(size: 16))
                .foregroundColor(Color.secondary)

            Button("Sign In") {
                NotificationCenter.default.post(name: .navigateToSignIn, object: nil)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.purple)
        }
    }
}

// MARK: - Apple Sign In Coordinator
class AppleSignInCoordinator: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showingError = false
    @Published var showingCreateAccountAlert = false

    private var currentNonce: String?
    private var isSignUpMode: Bool = false

    func signInWithApple(isSignUp: Bool = false) {
        isSignUpMode = isSignUp
        isLoading = true

        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                    self.showingError = true
                }
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Unable to fetch identity token"
                    self.showingError = true
                }
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Unable to serialize token string from data"
                    self.showingError = true
                }
                return
            }

            if isSignUpMode {
                handleSignUp(appleIDCredential: appleIDCredential, idTokenString: idTokenString, nonce: nonce)
            } else {
                handleSignIn(appleIDCredential: appleIDCredential, idTokenString: idTokenString, nonce: nonce)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            self.showingError = true
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first ?? ASPresentationAnchor()
    }

    // MARK: - Private Methods
    private func handleSignUp(appleIDCredential: ASAuthorizationAppleIDCredential, idTokenString: String, nonce: String) {
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)

        Auth.auth().signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                    self.showingError = true
                    return
                }

                guard let user = authResult?.user else {
                    self.isLoading = false
                    self.errorMessage = "Failed to get user information"
                    self.showingError = true
                    return
                }

                let firstName = appleIDCredential.fullName?.givenName ?? ""
                let lastName = appleIDCredential.fullName?.familyName ?? ""
                let email = appleIDCredential.email ?? user.email ?? ""

                self.saveAppleUserProfile(
                    uid: user.uid,
                    email: email,
                    firstName: firstName,
                    lastName: lastName
                )
            }
        }
    }

    private func handleSignIn(appleIDCredential: ASAuthorizationAppleIDCredential, idTokenString: String, nonce: String) {
        let email = appleIDCredential.email ?? ""

        if !email.isEmpty {
            checkUserExistsByEmail(email: email, idTokenString: idTokenString, nonce: nonce)
        } else {
            authenticateWithFirebase(idTokenString: idTokenString, nonce: nonce)
        }
    }

    private func checkUserExistsByEmail(email: String, idTokenString: String, nonce: String) {
        let db = Firestore.firestore()

        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { querySnapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.isLoading = false
                        self.errorMessage = "Error checking account: \(error.localizedDescription)"
                        self.showingError = true
                        return
                    }

                    guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                        self.isLoading = false
                        self.showingCreateAccountAlert = true
                        return
                    }

                    self.authenticateWithFirebase(idTokenString: idTokenString, nonce: nonce)
                }
            }
    }

    private func authenticateWithFirebase(idTokenString: String, nonce: String) {
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: nil)

        Auth.auth().signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                    self.showingError = true
                    return
                }

                self.isLoading = false
                NotificationCenter.default.post(name: .dismissAuth, object: nil)
            }
        }
    }

    private func saveAppleUserProfile(uid: String, email: String, firstName: String, lastName: String) {
        let db = Firestore.firestore()

        let userData: [String: Any] = [
            "uid": uid,
            "firstName": firstName.isEmpty ? "Apple" : firstName,
            "lastName": lastName.isEmpty ? "User" : lastName,
            "email": email,
            "displayName": firstName.isEmpty && lastName.isEmpty ? "Apple User" : "\(firstName) \(lastName)",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "videosUploaded": 0,
            "friendsCount": 0,
            "weeksParticipated": 0,
            "profileImageURL": ""
        ]

        db.collection("users").document(uid).setData(userData) { error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Account created but failed to save profile: \(error.localizedDescription)"
                    self.showingError = true
                } else {
                    NotificationCenter.default.post(name: .dismissAuth, object: nil)
                }
            }
        }
    }

    // MARK: - Helper functions
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

