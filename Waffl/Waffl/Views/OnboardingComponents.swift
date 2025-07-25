//
//  OnboardingComponents.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI

struct AppLogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 80, height: 80)
            
            Image(systemName: "video.fill")
                .font(.system(size: 35))
                .foregroundColor(.white)
        }
        .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct FeatureCard: View {
    let feature: OnboardingFeature
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 35))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.primary)
                
                Text(feature.description)
                    .font(.system(size: 16))
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct PageIndicatorView: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.orange : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentPage == index ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

struct OnboardingButtonsView: View {
    @State private var showingSignUp = false
    @State private var showingSignIn = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingSignUp = true
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
                showingSignIn = true
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
            
            TermsAndPrivacyView()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .fullScreenCover(isPresented: $showingSignUp) {
            AuthCoordinatorView(initialState: .signUp)
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            AuthCoordinatorView(initialState: .signIn)
        }
    }
}
