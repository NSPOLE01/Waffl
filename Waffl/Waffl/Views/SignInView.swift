//
//  SignInView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    
    var body: some View {
        NavigationView {
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
                SignInHeaderView()
                
                // Form
                SignInFormView(
                    email: $email,
                    password: $password,
                    isShowingPassword: $isShowingPassword
                )
                
                // Sign In Button
                SignInButtonView(email: email, password: password)
                
                // Or divider
                OrDividerView()
                
                // Google Sign In Button
                GoogleSignInButtonView()
                
                Spacer()
                
                // Sign Up Link
                SignUpLinkView()
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
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
    
    var body: some View {
        Button(action: {
            // Sign in action - here you would handle authentication
            // For now, we'll just dismiss the auth flow
            NotificationCenter.default.post(name: .dismissAuth, object: nil)
        }) {
            Text("Sign In")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.orange)
                .cornerRadius(12)
        }
        .disabled(email.isEmpty || password.isEmpty)
        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
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
    var body: some View {
        Button(action: {
            // Google sign in action
            print("Google Sign In tapped")
        }) {
            HStack(spacing: 12) {
                // Google Logo
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
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
    }
}
