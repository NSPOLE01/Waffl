//
//  BrowseVideosView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct BrowseVideosView: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var selectedTab: Int
    @State private var videos: [WaffleVideo] = []
    @State private var showingFriends = false
    @State private var isLoadingVideos = true
    @State private var selectedUser: WaffleUser?
    @State private var showingUserProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Videos Section
                    if isLoadingVideos {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading videos...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else if videos.isEmpty {
                        // Centered empty state that takes remaining space
                        VStack {
                            Spacer()
                            EmptyVideosView()
                            Spacer()
                        }
                        .frame(minHeight: 400) // Ensure minimum height for centering
                    } else {
                        ForEach(videos) { video in
                            VideoCard(video: video)
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadVideos()
            }
            .refreshable {
                loadVideos()
            }
            .fullScreenCover(isPresented: $showingFriends) {
                FriendsView()
            }
            .fullScreenCover(isPresented: $showingUserProfile) {
                if let user = selectedUser {
                    UserProfileView(user: user)
                        .environmentObject(authManager)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVideo"))) { notification in
                if let videoId = notification.userInfo?["videoId"] as? String {
                    navigateToVideo(videoId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToUserProfile"))) { notification in
                if let userId = notification.userInfo?["userId"] as? String {
                    navigateToUser(userId)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Waffl Wednesday")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("This week's moments from your friends")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Spacer()

                // Notification Bell
                NotificationBellButton(selectedTab: $selectedTab, onVideoSelected: { videoId in
                    navigateToVideo(videoId)
                }, onUserSelected: { userId in
                    navigateToUser(userId)
                })
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                // Consume taps to prevent falling through to videos
            }
            
            // Quick stats
            HStack(spacing: 20) {
                Button(action: {
                    showingFriends = true
                }) {
                    StatCard(title: "Friends", value: "\(authManager.currentUserProfile?.friendsCount ?? 0)", icon: "person.2.fill")
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(RoundedRectangle(cornerRadius: 12))
                
                StatCard(title: "Videos", value: "\(videos.count)", icon: "video.fill")
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        // Consume tap to prevent falling through
                    }
                
                StatCard(title: "Streak", value: "\(authManager.currentUserProfile?.currentStreak ?? 0)", icon: "flame.fill")
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        // Consume tap to prevent falling through
                    }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func loadVideos() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found")
            isLoadingVideos = false
            return
        }
        
        isLoadingVideos = true
        let db = Firestore.firestore()
        
        // First, get the user's following list to show videos from friends
        db.collection("users").document(currentUserId).collection("following").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error loading following list: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingVideos = false
                }
                return
            }
            
            let followingIds = snapshot?.documents.compactMap { $0.documentID } ?? []
            // Don't include current user's own videos in browse view
            
            // If user has no friends, show empty state
            if followingIds.isEmpty {
                DispatchQueue.main.async {
                    self.isLoadingVideos = false
                    self.videos = []
                }
                return
            }
            
            // Now get videos from these users
            self.loadVideosFromUsers(userIds: followingIds, currentUserId: currentUserId)
        }
    }
    
    private func loadVideosFromUsers(userIds: [String], currentUserId: String) {
        let db = Firestore.firestore()
        
        // Get videos from followed users (and current user)
        db.collection("videos")
            .whereField("authorId", in: userIds)
            .order(by: "uploadDate", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingVideos = false
                    
                    if let error = error {
                        print("❌ Error loading videos: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No videos found")
                        self.videos = []
                        return
                    }
                    
                    let loadedVideos = documents.compactMap { document in
                        try? WaffleVideo(from: document, currentUserId: currentUserId)
                    }
                    
                    self.videos = loadedVideos
                    print("✅ Loaded \(loadedVideos.count) videos")
                }
            }
    }
    
    private func navigateToVideo(_ videoId: String) {
        // Find the video in our current list
        if let video = videos.first(where: { $0.id == videoId }) {
            // For now, we can scroll to that video or highlight it
            // In a more complex implementation, you might navigate to a dedicated video view
            print("🎥 Navigating to video: \(video.id)")
        } else {
            // Video not in current list, could load it separately
            print("🎥 Video \(videoId) not found in current feed")
        }
    }

    private func navigateToUser(_ userId: String) {
        // Load user data and show profile
        let db = Firestore.firestore()

        db.collection("users").whereField("uid", isEqualTo: userId).getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading user: \(error.localizedDescription)")
                    return
                }

                guard let document = snapshot?.documents.first else {
                    print("⚠️ User not found: \(userId)")
                    return
                }

                do {
                    let user = try WaffleUser(from: document)
                    self.selectedUser = user
                    self.showingUserProfile = true
                    print("👤 Navigating to user profile: \(user.displayName)")
                } catch {
                    print("❌ Error parsing user data: \(error)")
                }
            }
        }
    }
}
