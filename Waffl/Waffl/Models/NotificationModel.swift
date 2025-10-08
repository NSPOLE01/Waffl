//
//  NotificationModel.swift
//  Waffl
//
//  Created by Claude on 10/7/25.
//

import Foundation
import Firebase
import FirebaseFirestore

enum NotificationType: String, CaseIterable {
    case like = "like"
    case comment = "comment"
    case follow = "follow"

    var title: String {
        switch self {
        case .like:
            return "liked your video"
        case .comment:
            return "commented on your video"
        case .follow:
            return "started following you"
        }
    }

    var icon: String {
        switch self {
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.left.fill"
        case .follow:
            return "person.badge.plus.fill"
        }
    }
}

struct WaffleNotification: Identifiable, Codable {
    let id: String
    let recipientId: String  // User who receives the notification
    let senderId: String     // User who triggered the notification
    let senderName: String   // Display name of sender
    let senderProfileImageURL: String?
    let type: NotificationType
    let videoId: String?     // For likes/comments - which video
    let videoThumbnailURL: String? // Thumbnail of the video
    let commentText: String? // For comments - the actual comment text
    let createdAt: Date
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id, recipientId, senderId, senderName, senderProfileImageURL
        case type, videoId, videoThumbnailURL, commentText, createdAt, isRead
    }

    init(id: String = UUID().uuidString,
         recipientId: String,
         senderId: String,
         senderName: String,
         senderProfileImageURL: String? = nil,
         type: NotificationType,
         videoId: String? = nil,
         videoThumbnailURL: String? = nil,
         commentText: String? = nil,
         isRead: Bool = false) {
        self.id = id
        self.recipientId = recipientId
        self.senderId = senderId
        self.senderName = senderName
        self.senderProfileImageURL = senderProfileImageURL
        self.type = type
        self.videoId = videoId
        self.videoThumbnailURL = videoThumbnailURL
        self.commentText = commentText
        self.createdAt = Date()
        self.isRead = isRead
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        recipientId = try container.decode(String.self, forKey: .recipientId)
        senderId = try container.decode(String.self, forKey: .senderId)
        senderName = try container.decode(String.self, forKey: .senderName)
        senderProfileImageURL = try container.decodeIfPresent(String.self, forKey: .senderProfileImageURL)

        let typeString = try container.decode(String.self, forKey: .type)
        type = NotificationType(rawValue: typeString) ?? .like

        videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        videoThumbnailURL = try container.decodeIfPresent(String.self, forKey: .videoThumbnailURL)
        commentText = try container.decodeIfPresent(String.self, forKey: .commentText)

        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recipientId, forKey: .recipientId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(senderName, forKey: .senderName)
        try container.encodeIfPresent(senderProfileImageURL, forKey: .senderProfileImageURL)
        try container.encode(type.rawValue, forKey: .type)
        try container.encodeIfPresent(videoId, forKey: .videoId)
        try container.encodeIfPresent(videoThumbnailURL, forKey: .videoThumbnailURL)
        try container.encodeIfPresent(commentText, forKey: .commentText)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(isRead, forKey: .isRead)
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "recipientId": recipientId,
            "senderId": senderId,
            "senderName": senderName,
            "type": type.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "isRead": isRead
        ]

        if let senderProfileImageURL = senderProfileImageURL {
            dict["senderProfileImageURL"] = senderProfileImageURL
        }
        if let videoId = videoId {
            dict["videoId"] = videoId
        }
        if let videoThumbnailURL = videoThumbnailURL {
            dict["videoThumbnailURL"] = videoThumbnailURL
        }
        if let commentText = commentText {
            dict["commentText"] = commentText
        }

        return dict
    }

    static func fromFirestore(data: [String: Any], id: String) throws -> WaffleNotification {
        guard let recipientId = data["recipientId"] as? String,
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let typeString = data["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw NSError(domain: "NotificationModelError", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid notification data"])
        }

        return WaffleNotification(
            id: id,
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            senderProfileImageURL: data["senderProfileImageURL"] as? String,
            type: type,
            videoId: data["videoId"] as? String,
            videoThumbnailURL: data["videoThumbnailURL"] as? String,
            commentText: data["commentText"] as? String,
            isRead: data["isRead"] as? Bool ?? false
        )
    }

    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdAt)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: createdAt)
        }
    }
}