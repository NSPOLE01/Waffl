//
//  HomeScreenView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct HomeScreenView: View {
    @State private var selectedTab = 1 // Start with "Browse Videos" tab
    @StateObject private var pushNotificationManager = PushNotificationManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            // Browse Videos Tab
            BrowseVideosView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "video.fill")
                    Text("Browse Videos")
                }
                .tag(1)

            // My Groups Tab
            MyGroupsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("My Groups")
                }
                .tag(2)

            // Create Video Tab
            CreateVideoView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Video")
                }
                .tag(3)

            // Account Tab
            AccountView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Account")
                }
                .tag(4)
        }
        .accentColor(.purple)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToAccountTab"))) { _ in
            selectedTab = 4
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideo"))) { notification in
            selectedTab = 1 // Switch to Browse Videos tab
            if let videoId = notification.userInfo?["videoId"] as? String {
                // The video navigation will be handled by BrowseVideosView
                print("🎥 Push notification: Navigate to video \(videoId)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToUserProfile"))) { notification in
            selectedTab = 1 // Switch to Browse Videos tab
            if let userId = notification.userInfo?["userId"] as? String {
                // The user navigation will be handled by BrowseVideosView
                print("👤 Push notification: Navigate to user \(userId)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToNotifications"))) { _ in
            selectedTab = 1 // Switch to Browse Videos tab (where notification bell is)
        }
        .onAppear {
            pushNotificationManager.requestNotificationPermission()
        }
    }

}
