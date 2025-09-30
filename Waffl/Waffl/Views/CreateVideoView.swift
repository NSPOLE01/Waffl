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
    @State private var userGroups: [WaffleGroup] = []
    @State private var selectedGroup: WaffleGroup?
    @State private var isLoadingGroups = false
    
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
                    } else if let videoURL = recordedVideoURL {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Video recorded successfully!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
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
                    } else {
                        VStack(spacing: 12) {
                            if isUploading {
                                VStack(spacing: 8) {
                                    ProgressView(value: uploadProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                    
                                    Text("Uploading... \(Int(uploadProgress * 100))%")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                            } else if showingSuccessMessage {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.green)
                                    
                                    Text("Video uploaded successfully!")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            } else {
                                VStack(spacing: 16) {
                                    // Group selection
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Share to Group (Optional)")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)

                                        if isLoadingGroups {
                                            HStack {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                Text("Loading groups...")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 8)
                                        } else if userGroups.isEmpty {
                                            Text("No groups available")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                                .padding(.vertical, 8)
                                        } else {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 12) {
                                                    // "None" option
                                                    Button(action: {
                                                        selectedGroup = nil
                                                    }) {
                                                        VStack(spacing: 4) {
                                                            Image(systemName: "globe")
                                                                .font(.system(size: 20))
                                                                .foregroundColor(selectedGroup == nil ? .white : .purple)
                                                            Text("Public")
                                                                .font(.system(size: 12, weight: .medium))
                                                                .foregroundColor(selectedGroup == nil ? .white : .purple)
                                                        }
                                                        .frame(width: 80, height: 60)
                                                        .background(selectedGroup == nil ? Color.purple : Color.purple.opacity(0.1))
                                                        .cornerRadius(12)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(Color.purple, lineWidth: selectedGroup == nil ? 0 : 1)
                                                        )
                                                    }

                                                    // Group options
                                                    ForEach(userGroups) { group in
                                                        Button(action: {
                                                            selectedGroup = group
                                                        }) {
                                                            VStack(spacing: 4) {
                                                                Image(systemName: "person.3.fill")
                                                                    .font(.system(size: 20))
                                                                    .foregroundColor(selectedGroup?.id == group.id ? .white : .purple)
                                                                Text(group.name)
                                                                    .font(.system(size: 12, weight: .medium))
                                                                    .foregroundColor(selectedGroup?.id == group.id ? .white : .purple)
                                                                    .lineLimit(1)
                                                            }
                                                            .frame(width: 80, height: 60)
                                                            .background(selectedGroup?.id == group.id ? Color.purple : Color.purple.opacity(0.1))
                                                            .cornerRadius(12)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color.purple, lineWidth: selectedGroup?.id == group.id ? 0 : 1)
                                                            )
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 4)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    // Share button
                                    Button(action: {
                                        uploadVideo()
                                    }) {
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
                                }
                            }
                            
                            if !isUploading && !showingSuccessMessage {
                                Button(action: {
                                    recordedVideoURL = nil
                                    showingSuccessMessage = false
                                }) {
                                    Text("Record Again")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.purple)
                                }
                            } else if showingSuccessMessage {
                                Button(action: {
                                    recordedVideoURL = nil
                                    showingSuccessMessage = false
                                }) {
                                    Text("Record New Video")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.purple)
                                }
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

                    let loadedGroups = snapshot?.documents.compactMap { document in
                        try? WaffleGroup(from: document)
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
