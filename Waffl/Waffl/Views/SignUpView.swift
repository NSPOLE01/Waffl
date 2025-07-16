//
//  SignUpView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI

struct SignUpView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isShowingPassword = false
    @State private var isShowingConfirmPassword = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Back Button
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
                    SignUpHeaderView()
                    
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
                        confirmPassword: confirmPassword
                    )
                    
                    Spacer(minLength: 20)
                    
                    // Sign In Link
                    SignInLinkView()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
    }
}

struct SignUpHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Create Account")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.primary)
            
            Text("Join Waffle Wednesday and start sharing your weekly moments")
                .font(.system(size: 16))
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
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
        VStack(spacing: 20) {
            // Name Fields
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primary)
                    
                    TextField("John", text: $firstName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                VStack(alignment: .leading, spacing: 8) {
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
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.primary)
                
                HStack {
                    if isShowingConfirmPassword {
                        TextField("Confirm your password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm your password", text: $confirmPassword)
                    }
                    
                    Button(action: {
                        isShowingConfirmPassword.toggle()
                    }) {
                        Image(systemName: isShowingConfirmPassword ? "eye.slash" : "eye")
                            .foregroundColor(Color.secondary)
                    }
                }
                .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Password Requirements
            PasswordRequirementsView(password: password)
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
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 8
    }
    
    var body: some View {
        Button(action: {
            // Sign up action - here you would handle user registration
            // For now, we'll just dismiss the auth flow
            NotificationCenter.default.post(name: .dismissAuth, object: nil)
        }) {
            Text("Create Account")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.orange)
                .cornerRadius(12)
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
    }
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
            .foregroundColor(.orange)
        }
    }
}
