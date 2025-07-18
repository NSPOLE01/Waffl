//
//  HomeScreenView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct HomeScreenView: View {
    @State private var selectedTab = 1 // Start with "Browse Videos" tab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Browse Videos Tab
            BrowseVideosView()
                .tabItem {
                    Image(systemName: "video.fill")
                    Text("Browse Videos")
                }
                .tag(1)
            
            // Create Video Tab
            CreateVideoView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Video")
                }
                .tag(2)
            
            // Account Tab
            AccountView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Account")
                }
                .tag(3)
        }
        .accentColor(.orange)
        .navigationBarHidden(true)
    }
}

// MARK: - Browse Videos View
struct BrowseVideosView: View {
    @State private var videos: [WaffleVideo] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Waffle Wednesday")
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
                            StatCard(title: "Friends", value: "12", icon: "person.2.fill")
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

// MARK: - Create Video View
struct CreateVideoView: View {
    @State private var isRecording = false
    @State private var recordedVideoURL: URL?
    @State private var showingCamera = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Your Waffle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Share a 1-minute video of your week")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Recording status
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        if let videoURL = recordedVideoURL {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if recordedVideoURL != nil {
                        Text("Video recorded successfully!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text("No video recorded yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if recordedVideoURL == nil {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Record Video")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button(action: {
                                // TODO: Upload video to Firebase
                                uploadVideo()
                            }) {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up")
                                    Text("Share Video")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                recordedVideoURL = nil
                            }) {
                                Text("Record Again")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(videoURL: $recordedVideoURL)
        }
    }
    
    private func uploadVideo() {
        // TODO: Implement video upload to Firebase
        print("Uploading video...")
    }
}

// MARK: - Account View
struct AccountView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingSignOut = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Picture
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(spacing: 4) {
                        Text("John Doe") // TODO: Get from user data
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("john.doe@example.com") // TODO: Get from Firebase Auth
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)
                
                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("12")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Friends")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("8")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Videos")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("24")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Weeks")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Menu Options
                VStack(spacing: 16) {
                    AccountMenuButton(title: "Edit Profile", icon: "person.circle") {
                        // TODO: Navigate to edit profile
                    }
                    
                    AccountMenuButton(title: "Friends", icon: "person.2") {
                        // TODO: Navigate to friends list
                    }
                    
                    AccountMenuButton(title: "Settings", icon: "gear") {
                        // TODO: Navigate to settings
                    }
                    
                    AccountMenuButton(title: "Help & Support", icon: "questionmark.circle") {
                        // TODO: Navigate to help
                    }
                    
                    Button(action: {
                        showingSignOut = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                            
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .alert("Sign Out", isPresented: $showingSignOut) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func signOut() {
        authManager.signOut()
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct VideoCard: View {
    let video: WaffleVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video thumbnail/placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("\(video.duration)s")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Video info
            HStack {
                Image(systemName: video.authorAvatar)
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(video.uploadDate, style: .relative)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !video.isWatched {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct EmptyVideosView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No videos yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Be the first to share your week!\nTap the + button to get started.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
    }
}

struct AccountMenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct CameraView: View {
    @Binding var videoURL: URL?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                Text("Camera functionality will be implemented here")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                
                Spacer()
                
                Button(action: {
                    // Mock recording completion
                    videoURL = URL(string: "mock://video.mp4")
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Models
struct WaffleVideo: Identifiable {
    let id: String
    let authorName: String
    let authorAvatar: String
    let thumbnailURL: String?
    let duration: Int
    let uploadDate: Date
    let isWatched: Bool
}
