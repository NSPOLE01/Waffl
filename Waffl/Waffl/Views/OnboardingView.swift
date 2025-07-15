// OnboardingView.swift
import SwiftUI
import Foundation

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
                        AppLogoView()
                        
                        Text("Waffle Wednesday")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color.primary)
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
                        PageIndicatorView(currentPage: currentPage, totalPages: features.count)
                    }
                    
                    Spacer()
                    
                    // Sign In / Sign Up Buttons
                    OnboardingButtonsView()
                }
            }
        }
    }
}
