//
//  Comment.swift
//  Waffl
//
//  Created by Claude Code on 2025-09-02.
//

import Foundation
import FirebaseFirestore

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let videoId: String
    let authorId: String
    let authorName: String
    let authorProfileImageURL: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let likesCount: Int
    let isLikedByCurrentUser: Bool
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Manual initializer for creating Comment instances
    init(id: String = UUID().uuidString, videoId: String, authorId: String, authorName: String, authorProfileImageURL: String = "", content: String, createdAt: Date = Date(), updatedAt: Date = Date(), likesCount: Int = 0, isLikedByCurrentUser: Bool = false) {
        self.id = id
        self.videoId = videoId
        self.authorId = authorId
        self.authorName = authorName
        self.authorProfileImageURL = authorProfileImageURL
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likesCount = likesCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
    
    // Initialize from Firestore document
    init(from document: DocumentSnapshot, currentUserId: String) throws {
        let data = document.data()
        
        guard let videoId = data?["videoId"] as? String,
              let authorId = data?["authorId"] as? String,
              let authorName = data?["authorName"] as? String,
              let content = data?["content"] as? String,
              let createdAtTimestamp = data?["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data?["updatedAt"] as? Timestamp else {
            throw NSError(domain: "CommentModelError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid comment data"])
        }
        
        self.id = document.documentID
        self.videoId = videoId
        self.authorId = authorId
        self.authorName = authorName
        self.authorProfileImageURL = data?["authorProfileImageURL"] as? String ?? ""
        self.content = content
        self.createdAt = createdAtTimestamp.dateValue()
        self.updatedAt = updatedAtTimestamp.dateValue()
        self.likesCount = data?["likesCount"] as? Int ?? 0
        
        // Check if current user has liked this comment
        let likedBy = data?["likedBy"] as? [String] ?? []
        self.isLikedByCurrentUser = likedBy.contains(currentUserId)
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
            "videoId": videoId,
            "authorId": authorId,
            "authorName": authorName,
            "authorProfileImageURL": authorProfileImageURL,
            "content": content,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "likesCount": likesCount,
            "likedBy": [] // This will be managed separately for likes
        ]
    }
    
    // Formatted time ago string
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}