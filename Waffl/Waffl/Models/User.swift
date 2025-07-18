//
//  User.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/18/25.
//

import Foundation
import FirebaseFirestore

struct WaffleUser: Codable, Identifiable {
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
    
    // Computed properties
    var fullName: String {
        return "\(firstName) \(lastName)"
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
    }
    
    // Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        return [
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
            "profileImageURL": profileImageURL
        ]
    }
}
