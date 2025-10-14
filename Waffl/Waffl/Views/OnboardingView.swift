// OnboardingView.swift
import SwiftUI
import Foundation

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Clean logo and title
            VStack(spacing: 24) {
                // Minimal logo
                ZStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 64, height: 64)

                    Image(systemName: "video.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Waffl")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Weekly moments with friends")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
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
