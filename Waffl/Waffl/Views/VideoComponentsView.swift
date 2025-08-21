//
//  VideoComponents.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import AVFoundation

// MARK: - Video Card Component
struct VideoCard: View {
    let video: WaffleVideo
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var viewCount: Int
    @State private var showingLikesList = false
    @State private var showingVideoPlayer = false
    @State private var showHeartAnimation = false
    @EnvironmentObject var authManager: AuthManager
    
    init(video: WaffleVideo) {
        self.video = video
        self._isLiked = State(initialValue: video.isLikedByCurrentUser)
        self._likeCount = State(initialValue: video.likeCount)
        self._viewCount = State(initialValue: video.viewCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video thumbnail/placeholder
            ZStack {
                Button(action: {
                    showingVideoPlayer = true
                }) {
                    VideoThumbnailView(videoURL: video.videoURL, duration: video.duration)
                }
                .buttonStyle(PlainButtonStyle())
                .onTapGesture(count: 2) {
                    // Double tap to like
                    handleDoubleTapLike()
                }
                
                // Heart animation overlay
                if showHeartAnimation {
                    HeartAnimationView()
                        .allowsHitTesting(false)
                }
            }
            
            // Video info
            HStack {
                AuthorAvatarView(avatarString: video.authorAvatar)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Posted \(video.uploadDate.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Views and likes section
                HStack(spacing: 12) {
                    // View count with eye icon
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("\(viewCount)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Like section with separate buttons
                    HStack(spacing: 8) {
                        // Heart button for liking
                        Button(action: {
                            toggleLike()
                        }) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isLiked ? .red : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Like count button for showing who liked
                        if likeCount > 0 {
                            Button(action: {
                                showingLikesList = true
                            }) {
                                Text("\(likeCount)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingLikesList) {
            LikesListView(videoId: video.id)
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            VideoPlayerView(video: video, isLiked: $isLiked, likeCount: $likeCount, viewCount: $viewCount)
        }
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
    
    private func toggleLike() {
        // Optimistic UI update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
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

// MARK: - Empty Videos View
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

// MARK: - Likes List View
struct LikesListView: View {
    let videoId: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var likedUsers: [WaffleUser] = []
    @State private var isLoading = true
    @State private var followingStatuses: [String: Bool] = [:]
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading likes...")
                        .padding(.top, 40)
                    Spacer()
                } else if likedUsers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No likes yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(likedUsers) { user in
                                LikeUserRow(
                                    user: user,
                                    isFollowing: followingStatuses[user.id] ?? false,
                                    onFollowToggle: {
                                        toggleFollow(user: user)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
            }
            .navigationTitle("Likes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            loadLikedUsers()
        }
    }
    
    private func loadLikedUsers() {
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // First get the video document to get the likes array
        db.collection("videos").document(videoId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading video likes: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            guard let data = snapshot?.data(),
                  let likes = data["likes"] as? [String] else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // If no likes, return early
            if likes.isEmpty {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // Get user profiles for all users who liked the video
            let dispatchGroup = DispatchGroup()
            var users: [WaffleUser] = []
            var followingStatuses: [String: Bool] = [:]
            
            for userId in likes {
                dispatchGroup.enter()
                
                // Get user profile
                db.collection("users").document(userId).getDocument { userSnapshot, userError in
                    if let userError = userError {
                        print("❌ Error loading user \(userId): \(userError)")
                        dispatchGroup.leave()
                        return
                    }
                    
                    if let userSnapshot = userSnapshot {
                        do {
                            let waffleUser = try WaffleUser(from: userSnapshot)
                            users.append(waffleUser)
                            
                            // Check if current user is following this user
                            db.collection("users").document(currentUserId).collection("following").document(userId).getDocument { followSnapshot, followError in
                                followingStatuses[userId] = followSnapshot?.exists ?? false
                                dispatchGroup.leave()
                            }
                        } catch {
                            print("❌ Error parsing user \(userId): \(error)")
                            dispatchGroup.leave()
                        }
                    } else {
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.likedUsers = users
                self.followingStatuses = followingStatuses
                self.isLoading = false
            }
        }
    }
    
    private func toggleFollow(user: WaffleUser) {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found for follow operation")
            return
        }
        
        let db = Firestore.firestore()
        let isCurrentlyFollowing = followingStatuses[user.id] ?? false
        
        // Optimistic UI update
        followingStatuses[user.id] = !isCurrentlyFollowing
        
        if !isCurrentlyFollowing {
            // Follow user
            db.collection("users").document(currentUserId).collection("following").document(user.id).setData([
                "followedAt": Timestamp(date: Date())
            ]) { error in
                if let error = error {
                    print("❌ Error following user: \(error)")
                    // Revert on error
                    DispatchQueue.main.async {
                        self.followingStatuses[user.id] = false
                    }
                    return
                }
                
                // Add current user to the target user's followers
                db.collection("users").document(user.id).collection("followers").document(currentUserId).setData([
                    "followedAt": Timestamp(date: Date())
                ]) { error in
                    if let error = error {
                        print("❌ Error updating followers: \(error)")
                    } else {
                        print("✅ Successfully followed user: \(user.displayName)")
                    }
                }
            }
        } else {
            // Unfollow user
            db.collection("users").document(currentUserId).collection("following").document(user.id).delete { error in
                if let error = error {
                    print("❌ Error unfollowing user: \(error)")
                    // Revert on error
                    DispatchQueue.main.async {
                        self.followingStatuses[user.id] = true
                    }
                    return
                }
                
                // Remove current user from the target user's followers
                db.collection("users").document(user.id).collection("followers").document(currentUserId).delete { error in
                    if let error = error {
                        print("❌ Error updating followers: \(error)")
                    } else {
                        print("✅ Successfully unfollowed user: \(user.displayName)")
                    }
                }
            }
        }
    }
}

// MARK: - Like User Row
struct LikeUserRow: View {
    let user: WaffleUser
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @State private var showingUserProfile = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingUserProfile = true
            }) {
                HStack(spacing: 12) {
                    // Profile Picture
                    AuthorAvatarView(avatarString: user.profileImageURL.isEmpty ? "person.circle.fill" : user.profileImageURL)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(user.email)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Follow/Unfollow Button
            Button(action: onFollowToggle) {
                Text(isFollowing ? "Unfollow" : "Follow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isFollowing ? .red : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color.clear : Color.orange)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isFollowing ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(user: user)
        }
    }
}

// MARK: - Stat Card Component
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

// MARK: - Video Model
struct WaffleVideo: Identifiable, Codable {
    let id: String
    let authorId: String
    let authorName: String
    let authorAvatar: String
    let videoURL: String
    let thumbnailURL: String?
    let duration: Int
    let uploadDate: Date
    let isWatched: Bool
    let likeCount: Int
    let isLikedByCurrentUser: Bool
    let viewCount: Int
    
    // Initialize from Firestore document
    init(from document: DocumentSnapshot, currentUserId: String? = nil) throws {
        let data = document.data()
        
        guard let authorId = data?["authorId"] as? String,
              let authorName = data?["authorName"] as? String,
              let videoURL = data?["videoURL"] as? String,
              let duration = data?["duration"] as? Int,
              let uploadDateTimestamp = data?["uploadDate"] as? Timestamp else {
            throw NSError(domain: "VideoModelError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid video data"])
        }
        
        self.id = document.documentID
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = data?["authorAvatar"] as? String ?? "person.circle.fill"
        self.videoURL = videoURL
        self.thumbnailURL = data?["thumbnailURL"] as? String
        self.duration = duration
        self.uploadDate = uploadDateTimestamp.dateValue()
        self.isWatched = data?["isWatched"] as? Bool ?? false
        self.likeCount = data?["likeCount"] as? Int ?? 0
        self.viewCount = data?["viewCount"] as? Int ?? 0
        
        // Check if current user liked this video
        if let currentUserId = currentUserId,
           let likes = data?["likes"] as? [String] {
            self.isLikedByCurrentUser = likes.contains(currentUserId)
        } else {
            self.isLikedByCurrentUser = false
        }
    }
    
    // Initialize with parameters (for creating new videos)
    init(id: String = UUID().uuidString, authorId: String, authorName: String, authorAvatar: String, videoURL: String, thumbnailURL: String? = nil, duration: Int, uploadDate: Date = Date(), isWatched: Bool = false, likeCount: Int = 0, isLikedByCurrentUser: Bool = false, viewCount: Int = 0) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.uploadDate = uploadDate
        self.isWatched = isWatched
        self.likeCount = likeCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.viewCount = viewCount
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "authorId": authorId,
            "authorName": authorName,
            "authorAvatar": authorAvatar,
            "videoURL": videoURL,
            "duration": duration,
            "uploadDate": Timestamp(date: uploadDate),
            "isWatched": isWatched,
            "likeCount": likeCount,
            "likes": [], // Initialize with empty likes array
            "viewCount": viewCount
        ]
        
        if let thumbnailURL = thumbnailURL {
            dict["thumbnailURL"] = thumbnailURL
        }
        
        return dict
    }
}

// MARK: - Heart Animation View
struct HeartAnimationView: View {
    @State private var isVisible = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80, weight: .bold))
            .foregroundColor(.red)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.2
                    opacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scale = 1.0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        scale = 0.8
                        opacity = 0.0
                    }
                }
            }
    }
}

// MARK: - Video Thumbnail Cache
class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Limit cache to 100 thumbnails
        cache.totalCostLimit = 50 * 1024 * 1024 // Limit cache to ~50MB
    }
    
    func getThumbnail(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func setThumbnail(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Estimate memory cost
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let videoURL: String
    let duration: Int
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
            
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            }
            
            // Overlay with play button and duration
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                
                Text("\(duration)s")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
        }
        .frame(height: 200) // Constrain the entire ZStack
        .clipped() // Ensure nothing extends beyond bounds
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // Check cache first
        if let cachedThumbnail = VideoThumbnailCache.shared.getThumbnail(for: videoURL) {
            self.thumbnail = cachedThumbnail
            self.isLoading = false
            return
        }
        
        // Generate new thumbnail
        generateThumbnail()
    }
    
    private func generateThumbnail() {
        guard let url = URL(string: videoURL) else {
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 300, height: 400) // Optimize for mobile
            
            do {
                let time = CMTime(seconds: 0.5, preferredTimescale: 600) // Get frame at 0.5 seconds
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                
                // Cache the thumbnail
                VideoThumbnailCache.shared.setThumbnail(image, for: self.videoURL)
                
                DispatchQueue.main.async {
                    self.thumbnail = image
                    self.isLoading = false
                }
            } catch {
                print("❌ Error generating thumbnail for \(self.videoURL): \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Author Avatar View
struct AuthorAvatarView: View {
    let avatarString: String
    
    var body: some View {
        Group {
            if avatarString.hasPrefix("http") {
                // It's a URL - use AsyncImage
                AsyncImage(url: URL(string: avatarString)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                // It's a system icon name
                Image(systemName: avatarString)
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
        }
    }
}
