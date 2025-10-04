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
    @Binding var isLiked: Bool
    @Binding var likeCount: Int
    @Binding var viewCount: Int
    @State private var showingLikesList = false
    @State private var showingComments = false
    @State private var commentCount: Int = 0
    @State private var isPlaying = false
    @State private var hasViewBeenCounted = false
    @State private var showHeartAnimation = false
    
    init(video: WaffleVideo, currentUserProfile: WaffleUser? = nil, isLiked: Binding<Bool>, likeCount: Binding<Int>, viewCount: Binding<Int>) {
        self.video = video
        self.currentUserProfile = currentUserProfile
        self._isLiked = isLiked
        self._likeCount = likeCount
        self._viewCount = viewCount
        self._commentCount = State(initialValue: video.commentCount)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen video player
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onTapGesture(count: 2) {
                            handleDoubleTapLike()
                        }
                        .onTapGesture {
                            togglePlayPause()
                        }
                } else {
                    // Loading state
                    Color.black
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        )
                }

                // Top overlay - User profile and close button
                VStack {
                    HStack {
                        // User profile info (left side)
                        HStack(spacing: 10) {
                            // Profile picture - use current user's if provided, otherwise use stored avatar
                            if let currentUserProfile = currentUserProfile, !currentUserProfile.profileImageURL.isEmpty {
                                AsyncImage(url: URL(string: currentUserProfile.profileImageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.white)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 6)
                            } else {
                                AuthorAvatarView(avatarString: video.authorAvatar)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1.5)
                                    )
                                    .shadow(color: .black.opacity(0.5), radius: 6)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(video.authorName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.7), radius: 3)

                                Text("Posted \(video.uploadDate.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.7), radius: 3)
                            }
                        }

                        Spacer()

                        // Close button (right side)
                        Button(action: {
                            player?.pause()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top)

                    Spacer()
                }

                // Bottom overlay - Stats and interactions
                VStack {
                    Spacer()

                    HStack(spacing: 16) {
                        // View count
                        HStack(spacing: 8) {
                            Image(systemName: "eye")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Text("\(viewCount)")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 5)

                        Spacer()

                        // Like and Comment section
                        HStack(spacing: 20) {
                            // Like section
                            HStack(spacing: 8) {
                                // Heart button
                                Button(action: {
                                    toggleLike()
                                }) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(isLiked ? .red : .white)
                                        .shadow(color: .black.opacity(0.5), radius: 3)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Like count button
                                if likeCount > 0 {
                                    Button(action: {
                                        showingLikesList = true
                                    }) {
                                        Text("\(likeCount)")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 3)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            // Comment section
                            HStack(spacing: 8) {
                                // Comment button
                                Button(action: {
                                    showingComments = true
                                }) {
                                    Image(systemName: "bubble.left")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 3)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Comment count
                                if commentCount > 0 {
                                    Text("\(commentCount)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 30)
                }

                // Heart animation overlay
                if showHeartAnimation {
                    HeartAnimationView()
                        .allowsHitTesting(false)
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
        .fullScreenCover(isPresented: $showingComments) {
            CommentsView(videoId: video.id) {
                refreshCommentCount()
            }
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
    
    private func handleDoubleTapLike() {
        // Only like if not already liked (prevent unlike on double tap)
        if !isLiked {
            isLiked = true
            likeCount += 1
            
            // Show heart animation
            showHeartAnimation = true
            
            // Hide animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showHeartAnimation = false
            }
            
            // Update Firebase
            updateLikeInFirebase()
        } else {
            // Still show animation even if already liked
            showHeartAnimation = true
            
            // Hide animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showHeartAnimation = false
            }
        }
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

    private func refreshCommentCount() {
        let db = Firestore.firestore()
        db.collection("videos").document(video.id).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error refreshing comment count: \(error)")
                return
            }

            guard let data = snapshot?.data(),
                  let newCommentCount = data["commentCount"] as? Int else {
                print("❌ Could not get comment count from document")
                return
            }

            DispatchQueue.main.async {
                self.commentCount = newCommentCount
            }
        }
    }
}