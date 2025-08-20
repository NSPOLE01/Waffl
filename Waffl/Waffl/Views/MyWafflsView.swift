//
//  MyWafflsView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct MyWafflsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var videos: [WaffleVideo] = []
    @State private var isLoadingVideos = true
    @State private var videoToDelete: WaffleVideo?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("My Waffls")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Your weekly moments and memories")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Video count
                            VStack {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(videos.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Quick stats
                        HStack(spacing: 20) {
                            StatCard(title: "Videos", value: "\(videos.count)", icon: "video.fill")
                            StatCard(title: "This Week", value: "\(getThisWeekVideosCount())", icon: "calendar")
                            StatCard(title: "Total Views", value: "\(getTotalViewsCount())", icon: "eye.fill")
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Videos Section
                    if isLoadingVideos {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading your videos...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else if videos.isEmpty {
                        EmptyMyVideosView()
                    } else {
                        ForEach(videos) { video in
                            MyWafflVideoCard(
                                video: video, 
                                currentUserProfile: authManager.currentUserProfile,
                                onDelete: {
                                    // Remove video from local array when deleted
                                    if let index = videos.firstIndex(where: { $0.id == video.id }) {
                                        videos.remove(at: index)
                                    }
                                },
                                onDeleteRequest: {
                                    // Set the video to delete, which will show the alert
                                    videoToDelete = video
                                }
                            )
                            .padding(.horizontal, 20)
                            .allowsHitTesting(true) // Ensure card allows hit testing
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadMyVideos()
            }
            .refreshable {
                loadMyVideos()
            }
            .alert("Delete Video", isPresented: .constant(videoToDelete != nil)) {
                Button("Cancel", role: .cancel) {
                    videoToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let video = videoToDelete {
                        deleteVideo(video)
                    }
                    videoToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this video? This action cannot be undone.")
            }
        }
    }
    
    private func loadMyVideos() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found")
            isLoadingVideos = false
            return
        }
        
        print("🔍 Loading videos for user ID: \(currentUserId)")
        isLoadingVideos = true
        let db = Firestore.firestore()
        
        // First, let's check all videos in the collection to debug
        db.collection("videos").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                print("📊 Total videos in collection: \(documents.count)")
                for doc in documents {
                    let data = doc.data()
                    if let authorId = data["authorId"] as? String {
                        print("📹 Video \(doc.documentID): authorId = \(authorId)")
                        if authorId == currentUserId {
                            print("✅ This video matches current user!")
                        }
                    }
                }
            }
        }
        
        // Get only videos uploaded by the current user
        db.collection("videos")
            .whereField("authorId", isEqualTo: currentUserId)
            .order(by: "uploadDate", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingVideos = false
                    
                    if let error = error {
                        print("❌ Error loading my videos: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents returned from query")
                        self.videos = []
                        return
                    }
                    
                    print("📊 Query returned \(documents.count) documents")
                    
                    let loadedVideos = documents.compactMap { document in
                        print("🔍 Processing document: \(document.documentID)")
                        do {
                            let video = try WaffleVideo(from: document, currentUserId: currentUserId)
                            print("✅ Successfully parsed video: \(video.id)")
                            return video
                        } catch {
                            print("❌ Failed to parse video \(document.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    // Videos are already sorted by the server-side query
                    self.videos = loadedVideos
                    print("✅ Final result: Loaded \(loadedVideos.count) videos for current user")
                }
            }
    }
    
    private func getThisWeekVideosCount() -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        return videos.filter { video in
            video.uploadDate >= startOfWeek
        }.count
    }
    
    private func getTotalViewsCount() -> Int {
        return videos.reduce(0) { total, video in
            total + video.viewCount
        }
    }
    
    private func deleteVideo(_ video: WaffleVideo) {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found for delete operation")
            return
        }
        
        // Only allow users to delete their own videos
        guard video.authorId == currentUserId else {
            print("❌ User cannot delete videos they didn't create")
            return
        }
        
        let db = Firestore.firestore()
        
        // Delete from Firestore
        db.collection("videos").document(video.id).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting video from Firestore: \(error.localizedDescription)")
                } else {
                    print("✅ Video deleted successfully from Firestore")
                    
                    // Update user's video count
                    self.updateUserVideoCount()
                    
                    // Remove video from local array
                    if let index = self.videos.firstIndex(where: { $0.id == video.id }) {
                        self.videos.remove(at: index)
                    }
                }
            }
        }
        
        // Also delete the video file from Firebase Storage
        deleteVideoFromStorage(video)
    }
    
    private func deleteVideoFromStorage(_ video: WaffleVideo) {
        let storage = Storage.storage()
        
        // Extract video file path from URL
        if let videoURL = URL(string: video.videoURL) {
            let videoRef = storage.reference(forURL: video.videoURL)
            
            videoRef.delete { error in
                if let error = error {
                    print("❌ Error deleting video file from Storage: \(error.localizedDescription)")
                } else {
                    print("✅ Video file deleted successfully from Storage")
                }
            }
        }
    }
    
    private func updateUserVideoCount() {
        guard let currentUser = authManager.currentUser else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).updateData([
            "videosUploaded": FieldValue.increment(Int64(-1))
        ]) { error in
            if let error = error {
                print("❌ Error updating video count after deletion: \(error.localizedDescription)")
            } else {
                print("✅ User video count updated after deletion")
                // Refresh user profile
                self.authManager.refreshUserProfile()
            }
        }
    }
}

// MARK: - Empty My Videos View
struct EmptyMyVideosView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No videos yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Start creating your weekly moments!\nTap 'Create Video' to get started.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - My Waffle Video Card (with current profile picture)
struct MyWafflVideoCard: View {
    let video: WaffleVideo
    let currentUserProfile: WaffleUser?
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var viewCount: Int
    @State private var showingLikesList = false
    @State private var showingVideoPlayer = false
    @State private var showHeartAnimation = false
    @State private var isDeleting = false
    @State private var showingUserProfile = false
    @EnvironmentObject var authManager: AuthManager
    
    let onDelete: () -> Void
    let onDeleteRequest: () -> Void
    
    init(video: WaffleVideo, currentUserProfile: WaffleUser?, onDelete: @escaping () -> Void, onDeleteRequest: @escaping () -> Void) {
        self.video = video
        self.currentUserProfile = currentUserProfile
        self.onDelete = onDelete
        self.onDeleteRequest = onDeleteRequest
        self._isLiked = State(initialValue: video.isLikedByCurrentUser)
        self._likeCount = State(initialValue: video.likeCount)
        self._viewCount = State(initialValue: video.viewCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button(action: {
                    print("🔍 Profile picture tapped for user: \(video.authorName)")
                    showingUserProfile = true
                }) {
                    if let profileImageURL = currentUserProfile?.profileImageURL, !profileImageURL.isEmpty {
                        AuthorAvatarView(avatarString: profileImageURL)
                    } else {
                        AuthorAvatarView(avatarString: "person.circle.fill")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Circle())
                Button(action: {
                    print("🔍 Author name tapped for user: \(video.authorName)")
                    showingUserProfile = true
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.authorName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Posted \(video.uploadDate.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle()) // Only the text area is tappable
                
                Spacer()
                    
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color.clear) // Clean background
            .allowsHitTesting(true) // Allow specific button interactions
            .frame(maxWidth: .infinity) // Take full width
            
            // SEPARATE VIDEO CONTAINER - COMPLETELY ISOLATED 
            VStack(spacing: 0) {
                ZStack {
                    // Base container with strict boundaries
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                    
                    // Video content with precise tap area
                    VideoThumbnailView(videoURL: video.videoURL, duration: video.duration)
                        .frame(height: 200)
                        .clipped()
                        .contentShape(Rectangle()) // Define exact video tap area
                        .onTapGesture {
                            print("🔍 Video thumbnail onTapGesture triggered for video: \(video.id)")
                            showingVideoPlayer = true
                        }
                        .onTapGesture(count: 2) {
                            print("🔍 Video thumbnail double-tap triggered for video: \(video.id)")
                            handleDoubleTapLike()
                        }
                    
                    // Delete button overlay (positioned absolutely)
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                onDeleteRequest()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                            .allowsHitTesting(true) // Ensure delete button works
                        }
                        Spacer()
                    }
                    .allowsHitTesting(true) // Allow delete button interaction
                    
                    // Heart animation overlay
                    if showHeartAnimation {
                        HeartAnimationView()
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                .clipped()
            }
            .frame(height: 200) // Strict constraint on video container
            .clipped() // Ensure nothing extends beyond video container
            .allowsHitTesting(true) // Allow video interaction only
            .background(Color.clear) // Clean video background
            .contentShape(Rectangle()) // Define exact boundaries for the video container
            
            // SEPARATE ENGAGEMENT BUTTONS CONTAINER - COMPLETELY ISOLATED
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // View count with eye icon
                    Button(action: {
                        print("🔍 View count tapped (no action) for video: \(video.id)")
                        // Just display, no action needed
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("\(viewCount)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .allowsHitTesting(true)
                    
                    // Like section - isolated button
                    Button(action: {
                        print("🔍 Like button tapped for video: \(video.id)")
                        toggleLike()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isLiked ? .red : .gray)
                                .animation(.easeInOut(duration: 0.2), value: isLiked)
                            
                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .allowsHitTesting(true)
                    
                    Spacer()
                    
                    // Like count button for showing who liked
                    if likeCount > 0 {
                        Button(action: {
                            showingLikesList = true
                        }) {
                            Text("See likes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .allowsHitTesting(true)
                    }
                }
                .padding(.horizontal, 4)
            }
            .allowsHitTesting(true) // Allow engagement button interactions
            .frame(maxWidth: .infinity) // Take full width
            .background(Color.clear) // Clean engagement background
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .allowsHitTesting(!isDeleting) // Prevent all interactions if deleting
        .opacity(isDeleting ? 0.6 : 1.0)
        .overlay(
            // Deleting indicator
            isDeleting ? 
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Deleting...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                )
            : nil
        )
        .sheet(isPresented: $showingLikesList) {
            LikesListView(videoId: video.id)
        }
        .sheet(isPresented: $showingUserProfile) {
            // Since this is the user's own video, show their own profile
            if let userProfile = currentUserProfile {
                UserProfileView(user: userProfile)
            } else {
                // Fallback - create a temporary user profile from video data
                UserProfileView(user: WaffleUser(
                    id: video.authorId,
                    email: "", // We don't have email from video data
                    displayName: video.authorName,
                    createdAt: video.uploadDate, // Use upload date as fallback
                    profileImageURL: video.authorAvatar.hasPrefix("http") ? video.authorAvatar : ""
                ))
            }
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            VideoPlayerView(video: video, currentUserProfile: currentUserProfile)
        }
    }
    
    private func handleDoubleTapLike() {
        print("🔍 handleDoubleTapLike called for video: \(video.id)")
        print("🔍 Current like state: \(isLiked)")
        
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
    
    private func toggleLike() {
        print("🔍 MyWafflVideoCard toggleLike called for video: \(video.id)")
        print("🔍 Current like state - isLiked: \(isLiked), likeCount: \(likeCount)")
        
        // Optimistic UI update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        print("🔍 After toggle - isLiked: \(isLiked), likeCount: \(likeCount)")
        
        // Update Firebase
        updateLikeInFirebase()
    }
    
    private func incrementViewCount() {
        // Optimistic UI update
        viewCount += 1
        
        // Update Firebase
        updateViewCountInFirebase()
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
        print("🔍 MyWafflVideoCard updateLikeInFirebase called for video: \(video.id)")
        
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found for like operation")
            return
        }
        
        print("🔍 Current user ID: \(currentUserId)")
        
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
