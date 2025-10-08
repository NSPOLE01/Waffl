//
//  NotificationBellButton.swift
//  Waffl
//
//  Created by Claude on 10/7/25.
//

import SwiftUI

struct NotificationBellButton: View {
    @StateObject private var notificationManager = NotificationManager()
    @State private var showingNotifications = false
    @Binding var selectedTab: Int
    let onVideoSelected: (String) -> Void
    let onUserSelected: (String) -> Void

    var body: some View {
        Button(action: {
            showingNotifications = true
        }) {
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.purple)

                // Unread indicator
                if notificationManager.hasUnreadNotifications() {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .fullScreenCover(isPresented: $showingNotifications) {
            NotificationsView(selectedTab: $selectedTab, onVideoSelected: onVideoSelected, onUserSelected: onUserSelected)
        }
    }
}