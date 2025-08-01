//
//  BrowseVideosView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct BrowseVideosView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var videos: [WaffleVideo] = []
    @State private var showingFriends = false
    
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
                            
                            StatCard(title: "Videos", value: "8", icon: "video.fill")
                            StatCard(title: "Watched", value: "5", icon: "eye.fill")
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Videos Section
                    if videos.isEmpty {
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
            .fullScreenCover(isPresented: $showingFriends) {
                FriendsView()
            }
        }
    }
    
    private func loadVideos() {
        // TODO: Load videos from Firebase
        // For now, using mock data
        videos = [
            WaffleVideo(
                id: "1",
                authorName: "John Doe",
                authorAvatar: "person.circle.fill",
                thumbnailURL: nil,
                duration: 58,
                uploadDate: Date(),
                isWatched: false
            ),
            WaffleVideo(
                id: "2",
                authorName: "Sarah Johnson",
                authorAvatar: "person.circle.fill",
                thumbnailURL: nil,
                duration: 45,
                uploadDate: Date().addingTimeInterval(-3600),
                isWatched: true
            )
        ]
    }
    
    private func getCurrentWeekString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
}
