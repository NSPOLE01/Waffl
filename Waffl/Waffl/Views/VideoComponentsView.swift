//
//  VideoComponents.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - Video Card Component
struct VideoCard: View {
    let video: WaffleVideo
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @EnvironmentObject var authManager: AuthManager
    
    init(video: WaffleVideo) {
        self.video = video
        self._isLiked = State(initialValue: video.isLikedByCurrentUser)
        self._likeCount = State(initialValue: video.likeCount)
    }
    
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
                
                // Like button overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            toggleLike()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(isLiked ? .red : .white)
                                
                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }
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
    
    private func toggleLike() {
        // Optimistic UI update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        // TODO: Update Firebase
        updateLikeInFirebase()
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
        
        // Check if current user liked this video
        if let currentUserId = currentUserId,
           let likes = data?["likes"] as? [String] {
            self.isLikedByCurrentUser = likes.contains(currentUserId)
        } else {
            self.isLikedByCurrentUser = false
        }
    }
    
    // Initialize with parameters (for creating new videos)
    init(id: String = UUID().uuidString, authorId: String, authorName: String, authorAvatar: String, videoURL: String, thumbnailURL: String? = nil, duration: Int, uploadDate: Date = Date(), isWatched: Bool = false, likeCount: Int = 0, isLikedByCurrentUser: Bool = false) {
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
            "likes": [] // Initialize with empty likes array
        ]
        
        if let thumbnailURL = thumbnailURL {
            dict["thumbnailURL"] = thumbnailURL
        }
        
        return dict
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
