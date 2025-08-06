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
    @State private var videos: [WaffleVideo] = []
    @State private var showingFriends = false
    @State private var isLoadingVideos = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
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
                            
                            // Week indicator
                            VStack {
                                Text("Week of")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(getCurrentWeekString())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Quick stats
                        HStack(spacing: 20) {
                            Button(action: {
                                showingFriends = true
                            }) {
                                StatCard(title: "Friends", value: "\(authManager.currentUserProfile?.friendsCount ?? 0)", icon: "person.2.fill")
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            StatCard(title: "Videos", value: "\(videos.count)", icon: "video.fill")
                            StatCard(title: "Watched", value: "5", icon: "eye.fill")
                        }
                        .padding(.horizontal, 20)
                    }
                    
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
                        EmptyVideosView()
                    } else {
                        ForEach(videos) { video in
                            VideoCard(video: video)
                                .padding(.horizontal, 20)
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
    
    private func getCurrentWeekString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
}
