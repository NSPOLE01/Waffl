//
//  User.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/18/25.
//

import Foundation
import FirebaseFirestore

struct WaffleUser: Codable, Identifiable, Hashable {
    let id: String // This will be the Firebase Auth UID
    let uid: String
    let firstName: String
    let lastName: String
    let email: String
    let displayName: String
    let createdAt: Date
    let updatedAt: Date
    let videosUploaded: Int
    let friendsCount: Int
    let weeksParticipated: Int
    let profileImageURL: String
    let currentStreak: Int
    let lastPostDate: Date?
    
    // Computed properties
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(uid)
    }
    
    static func == (lhs: WaffleUser, rhs: WaffleUser) -> Bool {
        return lhs.id == rhs.id && lhs.uid == rhs.uid
    }
    
    // Manual initializer for creating WaffleUser instances
    init(id: String, uid: String? = nil, firstName: String = "", lastName: String = "", email: String, displayName: String, createdAt: Date = Date(), updatedAt: Date = Date(), videosUploaded: Int = 0, friendsCount: Int = 0, weeksParticipated: Int = 0, profileImageURL: String = "", currentStreak: Int = 0, lastPostDate: Date? = nil) {
        self.id = id
        self.uid = uid ?? id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.videosUploaded = videosUploaded
        self.friendsCount = friendsCount
        self.weeksParticipated = weeksParticipated
        self.profileImageURL = profileImageURL
        self.currentStreak = currentStreak
        self.lastPostDate = lastPostDate
    }
    
    // Initialize from Firestore document
    init(from document: DocumentSnapshot) throws {
        let data = document.data()
        
        guard let uid = data?["uid"] as? String,
              let firstName = data?["firstName"] as? String,
              let lastName = data?["lastName"] as? String,
              let email = data?["email"] as? String,
              let displayName = data?["displayName"] as? String,
              let createdAtTimestamp = data?["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data?["updatedAt"] as? Timestamp else {
            throw NSError(domain: "UserModelError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user data"])
        }
        
        self.id = document.documentID
        self.uid = uid
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAtTimestamp.dateValue()
        self.updatedAt = updatedAtTimestamp.dateValue()
        self.videosUploaded = data?["videosUploaded"] as? Int ?? 0
        self.friendsCount = data?["friendsCount"] as? Int ?? 0
        self.weeksParticipated = data?["weeksParticipated"] as? Int ?? 0
        self.profileImageURL = data?["profileImageURL"] as? String ?? ""
        self.currentStreak = data?["currentStreak"] as? Int ?? 0
        
        // Handle lastPostDate (can be nil)
        if let lastPostTimestamp = data?["lastPostDate"] as? Timestamp {
            self.lastPostDate = lastPostTimestamp.dateValue()
        } else {
            self.lastPostDate = nil
        }
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "displayName": displayName,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "videosUploaded": videosUploaded,
            "friendsCount": friendsCount,
            "weeksParticipated": weeksParticipated,
            "profileImageURL": profileImageURL,
            "currentStreak": currentStreak
        ]
        
        // Only include lastPostDate if it's not nil
        if let lastPostDate = lastPostDate {
            dict["lastPostDate"] = Timestamp(date: lastPostDate)
        }
        
        return dict
    }
}
