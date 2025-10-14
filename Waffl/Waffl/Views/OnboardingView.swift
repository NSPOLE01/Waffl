// OnboardingView.swift
import SwiftUI
import Foundation

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 0) {
            // App title at top
            Text("Waffl")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 80)

            Spacer()

            // Center logo and subtext
            VStack(spacing: 20) {
                // Larger logo
                ZStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 84, height: 84)

                    Image(systemName: "video.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }

                Text("Weekly moments with friends")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Streamlined buttons
            VStack(spacing: 12) {
                OnboardingButtonsView()
            }
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 32)
    }
}
