//
//  CreateVideoView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import AVFoundation
import AVKit

// Forward declaration for WaffleGroup to avoid conflicts
struct CreateVideoGroup: Identifiable {
    let id: String
    let name: String
    let memberCount: Int
}


struct CreateVideoView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isRecording = false
    @State private var recordedVideoURL: URL?
    @State private var showingCamera = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showingSuccessMessage = false
    @State private var hasPostedToday = false
    @State private var isCheckingDailyLimit = true
    @State private var userGroups: [CreateVideoGroup] = []
    @State private var selectedGroup: CreateVideoGroup?
    @State private var isLoadingGroups = false
    @State private var showingVideoReview = false
    @State private var videoApproved = false
    @State private var showingGroupSelection = false
    
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
                
                Spacer()
                
                VStack(spacing: 16) {
                    if hasPostedToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("You've already shared today!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Come back tomorrow to share another video")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else if recordedVideoURL != nil {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Uploading your video...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        } else if showingSuccessMessage {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("Video uploaded successfully!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.1))
                                    .frame(width: 120, height: 120)

                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.purple)
                            }

                            Text("Video recorded! Processing...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                        }
                        
                        Text("No video recorded yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if isCheckingDailyLimit {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Checking today's posts...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    } else if hasPostedToday {
                        // No action buttons needed when user has already posted today
                        Spacer().frame(height: 0)
                    } else if recordedVideoURL == nil {
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
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    } else if showingSuccessMessage {
                        Button(action: {
                            recordedVideoURL = nil
                            showingSuccessMessage = false
                            videoApproved = false
                        }) {
                            Text("Record New Video")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.purple)
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
        .onChange(of: recordedVideoURL) { videoURL in
            if videoURL != nil {
                // Automatically go to review when video is recorded
                showingVideoReview = true
            }
        }
        .sheet(isPresented: $showingVideoReview) {
            VideoReviewView(
                videoURL: recordedVideoURL,
                userGroups: userGroups,
                selectedGroup: $selectedGroup,
                isLoadingGroups: isLoadingGroups,
                onApprove: {
                    videoApproved = true
                    showingVideoReview = false
                    showingGroupSelection = true
                },
                onReject: {
                    recordedVideoURL = nil
                    showingVideoReview = false
                    videoApproved = false
                }
            )
        }
        .sheet(isPresented: $showingGroupSelection) {
            GroupSelectionSheet(
                userGroups: userGroups,
                selectedGroup: $selectedGroup,
                isLoadingGroups: isLoadingGroups,
                onShare: {
                    showingGroupSelection = false
                    uploadVideo()
                },
                onCancel: {
                    showingGroupSelection = false
                }
            )
        }
        .onAppear {
            checkDailyLimit()
            loadUserGroups()
        }
    }
    
    private func checkDailyLimit() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found")
            isCheckingDailyLimit = false
            return
        }
        
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Check if user has already posted a video today
        db.collection("videos")
            .whereField("authorId", isEqualTo: currentUserId)
            .whereField("uploadDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("uploadDate", isLessThan: Timestamp(date: endOfDay))
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isCheckingDailyLimit = false
                    
                    if let error = error {
                        print("❌ Error checking daily limit: \(error.localizedDescription)")
                        // Allow recording on error (fail open)
                        self.hasPostedToday = false
                        return
                    }
                    
                    let todaysVideos = snapshot?.documents.count ?? 0
                    self.hasPostedToday = todaysVideos >= 1
                }
            }
    }

    private func loadUserGroups() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found")
            return
        }

        isLoadingGroups = true
        let db = Firestore.firestore()

        // Load groups where the current user is a member
        db.collection("groups")
            .whereField("members", arrayContains: currentUserId)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingGroups = false

                    if let error = error {
                        print("❌ Error loading user groups: \(error.localizedDescription)")
                        return
                    }

                    let loadedGroups = snapshot?.documents.compactMap { document -> CreateVideoGroup? in
                        let data = document.data()
                        guard let name = data["name"] as? String else { return nil }
                        let memberCount = data["memberCount"] as? Int ?? 0
                        return CreateVideoGroup(id: document.documentID, name: name, memberCount: memberCount)
                    } ?? []

                    self.userGroups = loadedGroups
                    print("✅ Loaded \(loadedGroups.count) groups for video sharing")
                }
            }
    }

    private func uploadVideo() {
        guard let videoURL = recordedVideoURL,
              let currentUser = authManager.currentUser else {
            print("❌ No video or user found")
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // Create unique filename
        let videoId = UUID().uuidString
        let videoRef = storageRef.child("videos/\(currentUser.uid)/\(videoId).mov")
        
        // Get video duration
        let videoDuration = getVideoDuration(from: videoURL)
        
        // Upload video file
        let uploadTask = videoRef.putFile(from: videoURL, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Error uploading video: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isUploading = false
                }
                return
            }
            
            // Get download URL
            videoRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isUploading = false
                    }
                    return
                }
                
                guard let downloadURL = url else {
                    print("❌ No download URL")
                    DispatchQueue.main.async {
                        self.isUploading = false
                    }
                    return
                }
                
                // Save video metadata to Firestore
                self.saveVideoToFirestore(
                    videoId: videoId,
                    videoURL: downloadURL.absoluteString,
                    duration: videoDuration,
                    authorId: currentUser.uid,
                    groupId: self.selectedGroup?.id
                )
            }
        }
        
        // Monitor upload progress
        uploadTask.observe(.progress) { snapshot in
            let percentComplete = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            DispatchQueue.main.async {
                self.uploadProgress = percentComplete
            }
        }
    }
    
    private func saveVideoToFirestore(videoId: String, videoURL: String, duration: Int, authorId: String, groupId: String?) {
        guard let currentUserProfile = authManager.currentUserProfile else {
            print("❌ No current user profile")
            DispatchQueue.main.async {
                self.isUploading = false
            }
            return
        }
        
        let db = Firestore.firestore()
        
        let video = WaffleVideo(
            id: videoId,
            authorId: authorId,
            authorName: currentUserProfile.displayName,
            authorAvatar: currentUserProfile.profileImageURL.isEmpty ? "person.circle.fill" : currentUserProfile.profileImageURL,
            videoURL: videoURL,
            duration: duration,
            groupId: groupId
        )
        
        db.collection("videos").document(videoId).setData(video.toDictionary()) { error in
            DispatchQueue.main.async {
                self.isUploading = false
                
                if let error = error {
                    print("❌ Error saving video to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Video saved successfully!")
                    self.showingSuccessMessage = true
                    self.hasPostedToday = true
                    
                    // Update user's video count and streak
                    self.updateUserVideoCount()
                    self.authManager.updateStreakForVideoPost()
                }
            }
        }
    }
    
    private func updateUserVideoCount() {
        guard let currentUser = authManager.currentUser else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "videosUploaded": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("❌ Error updating video count: \(error.localizedDescription)")
            } else {
                print("✅ User video count updated")
                // Refresh user profile
                self.authManager.refreshUserProfile()
            }
        }
    }
    
    private func getVideoDuration(from url: URL) -> Int {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let seconds = CMTimeGetSeconds(duration)
        return Int(seconds.rounded())
    }
}

// MARK: - Video Review View
struct VideoReviewView: View {
    let videoURL: URL?
    let userGroups: [CreateVideoGroup]
    @Binding var selectedGroup: CreateVideoGroup?
    let isLoadingGroups: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var showingShareSelection = false
    @State private var player: AVPlayer?

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                Text("Review Your Video")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 60)

                Spacer()

                // Video player
                if let videoURL = videoURL {
                    VideoPlayer(player: player ?? AVPlayer())
                        .frame(height: 500)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onAppear {
                            player = AVPlayer(url: videoURL)
                            player?.play()
                        }
                        .onDisappear {
                            player?.pause()
                        }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 400)
                        .cornerRadius(12)
                        .overlay(
                            Text("No video available")
                                .foregroundColor(.secondary)
                        )
                        .padding(.horizontal)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showingShareSelection = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve & Choose Where to Share")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.green)
                        .cornerRadius(12)
                    }

                    Button(action: onReject) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Record Again")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingShareSelection) {
            GroupSelectionSheet(
                userGroups: userGroups,
                selectedGroup: $selectedGroup,
                isLoadingGroups: isLoadingGroups,
                onShare: {
                    showingShareSelection = false
                    onApprove()
                },
                onCancel: {
                    showingShareSelection = false
                }
            )
        }
    }
}

// MARK: - Group Selection Sheet
struct GroupSelectionSheet: View {
    let userGroups: [CreateVideoGroup]
    @Binding var selectedGroup: CreateVideoGroup?
    let isLoadingGroups: Bool
    let onShare: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Share Your Video")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 30)

                if isLoadingGroups {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading groups...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Public option
                            Button(action: {
                                selectedGroup = nil
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 24))
                                        .foregroundColor(.purple)
                                        .frame(width: 40, height: 40)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(20)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Share Publicly")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)

                                        Text("Visible to all your friends")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedGroup == nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(16)
                                .background(selectedGroup == nil ? Color.purple.opacity(0.1) : Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedGroup == nil ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Group options
                            ForEach(userGroups) { group in
                                Button(action: {
                                    selectedGroup = group
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.purple)
                                            .frame(width: 40, height: 40)
                                            .background(Color.purple.opacity(0.1))
                                            .cornerRadius(20)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)

                                            Text("\(group.memberCount) members")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        if selectedGroup?.id == group.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.purple)
                                        }
                                    }
                                    .padding(16)
                                    .background(selectedGroup?.id == group.id ? Color.purple.opacity(0.1) : Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedGroup?.id == group.id ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: onShare) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                Text(selectedGroup == nil ? "Share Publicly" : "Share to \(selectedGroup!.name)")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.purple)
                            .cornerRadius(12)
                        }

                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
