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
    
    // Initialize from Firestore document
    init(from document: DocumentSnapshot) throws {
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
    }
    
    // Initialize with parameters (for creating new videos)
    init(id: String = UUID().uuidString, authorId: String, authorName: String, authorAvatar: String, videoURL: String, thumbnailURL: String? = nil, duration: Int, uploadDate: Date = Date(), isWatched: Bool = false) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.uploadDate = uploadDate
        self.isWatched = isWatched
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
            "isWatched": isWatched
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
