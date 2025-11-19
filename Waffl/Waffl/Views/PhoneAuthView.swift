//
//  PhoneAuthView.swift
//  Waffl
//
//  Phone number authentication entry point
//

import SwiftUI
import Firebase
import FirebaseAuth

struct PhoneAuthView: View {
    @State private var phoneNumber = ""
    @State private var countryCode = "+1"
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingVerification = false
    @State private var verificationID = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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

                        Text("Sign Up")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.primary)

                        Spacer()
                    }
                    .padding(.top, 20)

                    // Phone Icon
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                        .padding(.top, 40)

                    // Title
                    VStack(spacing: 8) {
                        Text("Enter your phone number")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("We'll send you a verification code")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Phone Number Input
                    VStack(spacing: 16) {
                        // Country Code + Phone Number
                        HStack(spacing: 12) {
                            // Country Code Picker
                            Menu {
                                Button("+1 (US)") { countryCode = "+1" }
                                Button("+44 (UK)") { countryCode = "+44" }
                                Button("+91 (India)") { countryCode = "+91" }
                                Button("+86 (China)") { countryCode = "+86" }
                                Button("+81 (Japan)") { countryCode = "+81" }
                            } label: {
                                HStack {
                                    Text(countryCode)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }

                            // Phone Number TextField
                            TextField("Phone Number", text: $phoneNumber)
                                .font(.system(size: 16))
                                .keyboardType(.phonePad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .onChange(of: phoneNumber) { newValue in
                                    // Format phone number as user types
                                    phoneNumber = formatPhoneNumber(newValue)
                                }
                        }

                        // Helper Text
                        Text("Standard messaging rates may apply")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Continue Button
                    Button(action: sendVerificationCode) {
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
                    .background(isValidPhoneNumber ? Color.purple : Color.purple.opacity(0.5))
                    .cornerRadius(16)
                    .disabled(!isValidPhoneNumber || isLoading)
                    .padding(.top, 20)

                    Spacer()

                    // Sign In Link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)

                        Button(action: {
                            NotificationCenter.default.post(name: .navigateToSignIn, object: nil)
                        }) {
                            Text("Sign In")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showingVerification) {
                VerificationCodeView(
                    verificationID: verificationID,
                    phoneNumber: fullPhoneNumber
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var fullPhoneNumber: String {
        countryCode + phoneNumber.filter { $0.isNumber }
    }

    private var isValidPhoneNumber: Bool {
        let digitsOnly = phoneNumber.filter { $0.isNumber }
        return digitsOnly.count >= 10
    }

    // MARK: - Helper Functions

    private func formatPhoneNumber(_ number: String) -> String {
        // Remove non-numeric characters
        let digitsOnly = number.filter { $0.isNumber }

        // Limit to 10 digits for US numbers
        let limited = String(digitsOnly.prefix(10))

        // Format as (XXX) XXX-XXXX
        if limited.count <= 3 {
            return limited
        } else if limited.count <= 6 {
            let areaCode = limited.prefix(3)
            let prefix = limited.dropFirst(3)
            return "(\(areaCode)) \(prefix)"
        } else {
            let areaCode = limited.prefix(3)
            let prefix = limited.dropFirst(3).prefix(3)
            let lineNumber = limited.dropFirst(6)
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        }
    }

    // MARK: - Authentication

    private func sendVerificationCode() {
        isLoading = true

        print("📱 Sending verification code to: \(fullPhoneNumber)")

        PhoneAuthProvider.provider().verifyPhoneNumber(fullPhoneNumber, uiDelegate: nil) { verificationID, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    print("❌ Error sending verification code: \(error.localizedDescription)")
                    self.errorMessage = "Failed to send verification code. Please check your phone number and try again."
                    self.showingError = true
                    return
                }

                guard let verificationID = verificationID else {
                    print("❌ No verification ID received")
                    self.errorMessage = "Something went wrong. Please try again."
                    self.showingError = true
                    return
                }

                print("✅ Verification code sent successfully")
                self.verificationID = verificationID
                self.showingVerification = true
            }
        }
    }
}
