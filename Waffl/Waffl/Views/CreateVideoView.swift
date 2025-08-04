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
                            if isUploading {
                                VStack(spacing: 8) {
                                    ProgressView(value: uploadProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                    
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
                                Button(action: {
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
                            }
                            
                            if !isUploading && !showingSuccessMessage {
                                Button(action: {
                                    recordedVideoURL = nil
                                    showingSuccessMessage = false
                                }) {
                                    Text("Record Again")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                            } else if showingSuccessMessage {
                                Button(action: {
                                    recordedVideoURL = nil
                                    showingSuccessMessage = false
                                }) {
                                    Text("Record New Video")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.orange)
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
                    authorId: currentUser.uid
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
    
    private func saveVideoToFirestore(videoId: String, videoURL: String, duration: Int, authorId: String) {
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
            duration: duration
        )
        
        db.collection("videos").document(videoId).setData(video.toDictionary()) { error in
            DispatchQueue.main.async {
                self.isUploading = false
                
                if let error = error {
                    print("❌ Error saving video to Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Video saved successfully!")
                    self.showingSuccessMessage = true
                    
                    // Update user's video count
                    self.updateUserVideoCount()
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
