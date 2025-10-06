//
//  HelpSupportView.swift
//  Waffl
//
//  Created by Claude on 10/6/25.
//

import SwiftUI

struct HelpSupportView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)

                    VStack(spacing: 16) {
                        Text("Need Help?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("For all concerns and support requests, please email us at:")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Button(action: {
                            if let url = URL(string: "mailto:help@waffl.com") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("help@waffl.com")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }

                        Text("We'll get back to you as soon as possible!")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
        }
    }
}