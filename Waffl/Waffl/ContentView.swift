import SwiftUI

struct ContentView: View {
    var body: some View {
        OnboardingView()
    }
}

struct OnboardingView: View {
    @State private var currentPage = 0
    private let features = [
        OnboardingFeature(
            icon: "calendar.badge.clock",
            title: "Weekly Connection",
            description: "Every Wednesday, share a 1-minute video of your week with friends"
        ),
        OnboardingFeature(
            icon: "person.2.fill",
            title: "Stay Connected",
            description: "Keep up with your friends' lives through authentic weekly updates"
        ),
        OnboardingFeature(
            icon: "heart.fill",
            title: "Real Moments",
            description: "Share genuine moments instead of just sending reels to each other"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.1),
                        Color.orange.opacity(0.05),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo and App Name
                    VStack(spacing: 20) {
                        // App Icon
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "video.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Waffle Wednesday")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Feature Carousel
                    VStack(spacing: 40) {
                        TabView(selection: $currentPage) {
                            ForEach(0..<features.count, id: \.self) { index in
                                FeatureCard(feature: features[index])
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 200)
                        
                        // Page Indicators
                        HStack(spacing: 8) {
                            ForEach(0..<features.count, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? Color.orange : Color.gray.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Sign In / Sign Up Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            // Sign Up Action
                        }) {
                            Text("Create Account")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Sign In Action
                        }) {
                            Text("Sign In")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange, lineWidth: 2)
                                )
                        }
                        
                        // Terms and Privacy
                        VStack(spacing: 8) {
                            Text("By continuing, you agree to our")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Button("Terms of Service") {
                                    // Terms action
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                                
                                Text("and")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Privacy Policy") {
                                    // Privacy action
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct FeatureCard: View {
    let feature: OnboardingFeature
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 35))
                    .foregroundColor(.orange)
            }
            
            // Title and Description
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(feature.description)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome Back")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Sign in to continue sharing your weekly moments")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
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
                                    .foregroundColor(.secondary)
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
                
                // Sign In Button
                Button(action: {
                    // Sign in action
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
                
                Spacer()
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Button("Sign Up") {
                        // Navigate to sign up
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .font(.system(size: 16))
    }
}

// MARK: - Data Models
struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        
        ContentView()
            .preferredColorScheme(.dark)
    }
}
