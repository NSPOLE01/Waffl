//
//  VerificationCodeView.swift
//  Waffl
//
//  6-digit verification code entry
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct VerificationCodeView: View {
    let verificationID: String
    let phoneNumber: String

    @State private var code: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingNameEntry = false
    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header with Back Button
                HStack {
                    Button(action: {
                        // Go back to phone number entry
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)

                Spacer()

                // Icon
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)

                // Title
                VStack(spacing: 8) {
                    Text("Enter verification code")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("We sent a code to \(phoneNumber)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // 6-Digit Code Input
                HStack(spacing: 12) {
                    ForEach(0..<6) { index in
                        CodeDigitField(
                            text: $code[index],
                            index: index,
                            focusedField: $focusedField,
                            onComplete: {
                                if index < 5 {
                                    focusedField = index + 1
                                } else {
                                    // All fields filled, verify code
                                    verifyCode()
                                }
                            },
                            onBackspace: {
                                if index > 0 {
                                    focusedField = index - 1
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Verify Button
                Button(action: verifyCode) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verify")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isCodeComplete ? Color.purple : Color.purple.opacity(0.5))
                .cornerRadius(16)
                .disabled(!isCodeComplete || isLoading)
                .padding(.horizontal, 24)
                .padding(.top, 30)

                // Resend Code
                Button(action: resendCode) {
                    Text("Didn't receive a code? Resend")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.purple)
                }
                .padding(.top, 16)

                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                // Auto-focus first field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = 0
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    // Clear code on error
                    code = Array(repeating: "", count: 6)
                    focusedField = 0
                }
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showingNameEntry) {
                NameEntryView(phoneNumber: phoneNumber)
            }
        }
    }

    // MARK: - Computed Properties

    private var isCodeComplete: Bool {
        code.allSatisfy { !$0.isEmpty }
    }

    private var verificationCode: String {
        code.joined()
    }

    // MARK: - Helper Functions

    private func dismiss() {
        // Dismiss this view to go back to phone number entry
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.dismiss(animated: true)
        }
    }

    // MARK: - Authentication

    private func verifyCode() {
        guard isCodeComplete else { return }

        isLoading = true
        print("🔐 Verifying code: \(verificationCode)")

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        Auth.auth().signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    print("❌ Error verifying code: \(error.localizedDescription)")
                    self.errorMessage = "Invalid verification code. Please try again."
                    self.showingError = true
                    return
                }

                guard let user = authResult?.user else {
                    print("❌ No user returned after verification")
                    self.errorMessage = "Something went wrong. Please try again."
                    self.showingError = true
                    return
                }

                print("✅ Phone verification successful for user: \(user.uid)")

                // Check if user profile exists
                checkUserProfile(uid: user.uid)
            }
        }
    }

    private func checkUserProfile(uid: String) {
        let db = Firestore.firestore()

        db.collection("users").document(uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    // User profile exists, sign in complete
                    print("✅ User profile exists, signing in")
                    NotificationCenter.default.post(name: .dismissAuth, object: nil)
                } else {
                    // New user, need to collect name
                    print("📝 New user, showing name entry")
                    self.showingNameEntry = true
                }
            }
        }
    }

    private func resendCode() {
        print("📱 Resending verification code to: \(phoneNumber)")

        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { newVerificationID, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error resending code: \(error.localizedDescription)")
                    self.errorMessage = "Failed to resend code. Please try again."
                    self.showingError = true
                    return
                }

                print("✅ Verification code resent successfully")
            }
        }
    }
}

// MARK: - Code Digit Field Component

struct CodeDigitField: View {
    @Binding var text: String
    let index: Int
    @FocusState.Binding var focusedField: Int?
    let onComplete: () -> Void
    let onBackspace: () -> Void

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 24, weight: .semibold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .frame(width: 48, height: 56)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .focused($focusedField, equals: index)
            .onChange(of: text) { newValue in
                // Only allow single digit
                if newValue.count > 1 {
                    text = String(newValue.prefix(1))
                }

                // Move to next field if digit entered
                if newValue.count == 1 {
                    onComplete()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                // Handle backspace
                if let textField = obj.object as? UITextField {
                    textField.deleteBackward()
                    if text.isEmpty {
                        onBackspace()
                    }
                }
            }
    }
}

// MARK: - Name Entry View (for new users)

struct NameEntryView: View {
    let phoneNumber: String

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Spacer()

                        Text("Complete Your Profile")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.primary)

                        Spacer()
                    }
                    .padding(.top, 20)

                    // Icon
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                        .padding(.top, 40)

                    // Title
                    VStack(spacing: 8) {
                        Text("What's your name?")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("This is how you'll appear to others")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }

                    // Name Fields
                    VStack(spacing: 16) {
                        // First Name
                        TextField("First Name", text: $firstName)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .autocapitalization(.words)

                        // Last Name
                        TextField("Last Name", text: $lastName)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .autocapitalization(.words)
                    }
                    .padding(.top, 20)

                    // Continue Button
                    Button(action: createUserProfile) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isValidName ? Color.purple : Color.purple.opacity(0.5))
                    .cornerRadius(16)
                    .disabled(!isValidName || isLoading)
                    .padding(.top, 20)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var isValidName: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - User Profile Creation

    private func createUserProfile() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No authenticated user found"
            showingError = true
            return
        }

        isLoading = true
        print("📝 Creating user profile for: \(user.uid)")

        let db = Firestore.firestore()

        let userData: [String: Any] = [
            "uid": user.uid,
            "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            "phoneNumber": phoneNumber,
            "displayName": "\(firstName) \(lastName)",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "videosUploaded": 0,
            "friendsCount": 0,
            "weeksParticipated": 0,
            "profileImageURL": ""
        ]

        db.collection("users").document(user.uid).setData(userData) { error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    print("❌ Error creating user profile: \(error.localizedDescription)")
                    self.errorMessage = "Failed to create profile. Please try again."
                    self.showingError = true
                    return
                }

                print("✅ User profile created successfully")
                NotificationCenter.default.post(name: .dismissAuth, object: nil)
            }
        }
    }
}
