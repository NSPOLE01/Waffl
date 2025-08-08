//
//  VideoPlayerView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Firebase
import FirebaseFirestore

struct VideoPlayerView: View {
    let video: WaffleVideo
    let currentUserProfile: WaffleUser? // For MyWaffls videos to show current profile pic
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var player: AVPlayer?
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var viewCount: Int
    @State private var showingLikesList = false
    @State private var isPlaying = false
    @State private var hasViewBeenCounted = false
    
    init(video: WaffleVideo, currentUserProfile: WaffleUser? = nil) {
        self.video = video
        self.currentUserProfile = currentUserProfile
        self._isLiked = State(initialValue: video.isLikedByCurrentUser)
        self._likeCount = State(initialValue: video.likeCount)
        self._viewCount = State(initialValue: video.viewCount)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Close button
                    HStack {
                        Button(action: {
                            player?.pause()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    
                    // Video Player
                    if let player = player {
                        VideoPlayer(player: player)
                            .aspectRatio(9/16, contentMode: .fit)
                            .clipped()
                            .onTapGesture {
                                togglePlayPause()
                            }
                    } else {
                        // Loading state
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(9/16, contentMode: .fit)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            )
                    }
                    
                    Spacer()
                    
                    // Video Info and Controls
                    VStack(spacing: 16) {
                        // Author info
                        HStack(spacing: 12) {
                            // Profile picture - use current user's if provided, otherwise use stored avatar
                            if let currentUserProfile = currentUserProfile {
                                if !currentUserProfile.profileImageURL.isEmpty {
                                    AuthorAvatarView(avatarString: currentUserProfile.profileImageURL)
                                } else {
                                    AuthorAvatarView(avatarString: "person.circle.fill")
                                }
                            } else {
                                AuthorAvatarView(avatarString: video.authorAvatar)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(video.authorName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Posted \(video.uploadDate.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                        }
                        
                        // Engagement metrics
                        HStack(spacing: 24) {
                            // View count
                            HStack(spacing: 6) {
                                Image(systemName: "eye")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("\(viewCount)")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Like section
                            HStack(spacing: 12) {
                                // Heart button
                                Button(action: {
                                    toggleLike()
                                }) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(isLiked ? .red : .white)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Like count button
                                if likeCount > 0 {
                                    Button(action: {
                                        showingLikesList = true
                                    }) {
                                        Text("\(likeCount)")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupAudioSession()
            setupVideoPlayer()
            incrementViewCount()
        }
        .onDisappear {
            player?.pause()
        }
        .sheet(isPresented: $showingLikesList) {
            LikesListView(videoId: video.id)
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for playback")
        } catch {
            print("❌ Failed to set audio session category: \(error)")
        }
    }
    
    private func setupVideoPlayer() {
        guard let videoURL = URL(string: video.videoURL) else {
            print("❌ Invalid video URL: \(video.videoURL)")
            return
        }
        
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Auto-play the video
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            player?.play()
            isPlaying = true
        }
        
        print("✅ Video player setup for URL: \(videoURL)")
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func incrementViewCount() {
        // Only count view once per session
        guard !hasViewBeenCounted else { return }
        hasViewBeenCounted = true
        
        // Optimistic UI update
        viewCount += 1
        
        // Update Firebase
        updateViewCountInFirebase()
    }
    
    private func toggleLike() {
        // Optimistic UI update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        // Update Firebase
        updateLikeInFirebase()
    }
    
    private func updateViewCountInFirebase() {
        let db = Firestore.firestore()
        let videoRef = db.collection("videos").document(video.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let videoDocument: DocumentSnapshot
            do {
                try videoDocument = transaction.getDocument(videoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = videoDocument.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve video data"])
                errorPointer?.pointee = error
                return nil
            }
            
            let currentViewCount = data["viewCount"] as? Int ?? 0
            
            transaction.updateData([
                "viewCount": currentViewCount + 1
            ], forDocument: videoRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ Transaction failed for video view count: \(error)")
                
                // Revert optimistic UI update on failure
                DispatchQueue.main.async {
                    self.viewCount -= 1
                }
            } else {
                print("✅ View count updated successfully for video: \(self.video.id)")
            }
        }
    }
    
    private func updateLikeInFirebase() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found for like operation")
            return
        }
        
        let db = Firestore.firestore()
        let videoRef = db.collection("videos").document(video.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let videoDocument: DocumentSnapshot
            do {
                try videoDocument = transaction.getDocument(videoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = videoDocument.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve video data"])
                errorPointer?.pointee = error
                return nil
            }
            
            var likes = data["likes"] as? [String] ?? []
            let currentLikeCount = data["likeCount"] as? Int ?? 0
            
            if self.isLiked {
                // Add like
                if !likes.contains(currentUserId) {
                    likes.append(currentUserId)
                    transaction.updateData([
                        "likes": likes,
                        "likeCount": currentLikeCount + 1
                    ], forDocument: videoRef)
                }
            } else {
                // Remove like
                if let index = likes.firstIndex(of: currentUserId) {
                    likes.remove(at: index)
                    transaction.updateData([
                        "likes": likes,
                        "likeCount": max(0, currentLikeCount - 1)
                    ], forDocument: videoRef)
                }
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ Transaction failed for video like: \(error)")
                
                // Revert optimistic UI update on failure
                DispatchQueue.main.async {
                    self.isLiked.toggle()
                    self.likeCount += self.isLiked ? 1 : -1
                }
            } else {
                print("✅ Like status updated successfully for video: \(self.video.id)")
            }
        }
    }
}