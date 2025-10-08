//
//  UserProfileView.swift
//  Waffl
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct UserProfileView: View {
    let user: WaffleUser
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isFollowing = false
    @State private var isLoadingFollowStatus = true
    @State private var totalLikes = 0
    @State private var isLoadingLikes = true
    @State private var mutualFriends: [WaffleUser] = []
    @State private var isLoadingMutuals = true
    @State private var showingUserFriends = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 16)
            
            VStack(spacing: 24) {
            
            // Profile Header
            VStack(spacing: 16) {
                // Profile Picture
                AsyncImage(url: URL(string: user.profileImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                        )
                }
                
                VStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.top, 10)
            
            // Stats
            HStack(spacing: 40) {
                VStack(spacing: 6) {
                    Text("\(user.videosUploaded)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Videos")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showingUserFriends = true
                }) {
                    VStack(spacing: 6) {
                        Text("\(user.friendsCount)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Friends")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(spacing: 6) {
                    if isLoadingLikes {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("\(totalLikes)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Text("Likes")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            // Mutual Friends Section
            if !mutualFriends.isEmpty {
                VStack(spacing: 8) {
                    Text("\(mutualFriends.count) mutual friend\(mutualFriends.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        let displayFriends = Array(mutualFriends.prefix(2))
                        ForEach(displayFriends.indices, id: \.self) { index in
                            let friend = displayFriends[index]
                            if index > 0 {
                                Text(",")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                            Text(friend.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }
            
            // Follow/Unfollow Button
            if isLoadingFollowStatus {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.vertical, 20)
            } else {
                Button(action: {
                    if isFollowing {
                        unfollowUser(user)
                    } else {
                        followUser(user)
                    }
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isFollowing ? .purple : .white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(isFollowing ? Color.purple.opacity(0.1) : Color.purple)
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.purple, lineWidth: isFollowing ? 1 : 0)
                        )
                }
            }
            
            Spacer()
            
            // Locked Profile Message (only show when not following)
            if !isLoadingFollowStatus && !isFollowing {
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("This profile is locked")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Follow to see content")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 60)
            }
            
            Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            checkFollowStatus()
            loadTotalLikes()
            loadMutualFriends()
        }
        .fullScreenCover(isPresented: $showingUserFriends) {
            UserFriendsView(user: user)
        }
    }
    
    
    private func loadMutualFriends() {
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoadingMutuals = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Get current user's following list
        db.collection("users").document(currentUserId).collection("following").getDocuments { currentSnapshot, currentError in
            
            if let currentError = currentError {
                print("❌ Error loading current user following: \(currentError.localizedDescription)")
                DispatchQueue.main.async {
                    isLoadingMutuals = false
                }
                return
            }
            
            let currentFollowingIds = currentSnapshot?.documents.compactMap { $0.documentID } ?? []
            
            // Get target user's following list
            db.collection("users").document(user.uid).collection("following").getDocuments { targetSnapshot, targetError in
                if let targetError = targetError {
                    print("❌ Error loading target user following: \(targetError.localizedDescription)")
                    DispatchQueue.main.async {
                        isLoadingMutuals = false
                    }
                    return
                }
                
                let targetFollowingIds = targetSnapshot?.documents.compactMap { $0.documentID } ?? []
                
                // Find mutual friend IDs
                let mutualIds = Set(currentFollowingIds).intersection(Set(targetFollowingIds))
                
                if mutualIds.isEmpty {
                    DispatchQueue.main.async {
                        mutualFriends = []
                        isLoadingMutuals = false
                    }
                    return
                }
                
                // Fetch mutual friends' user data
                db.collection("users").whereField("uid", in: Array(mutualIds)).getDocuments { mutualSnapshot, mutualError in
                    DispatchQueue.main.async {
                        isLoadingMutuals = false
                        
                        if let mutualError = mutualError {
                            print("❌ Error loading mutual friends: \(mutualError.localizedDescription)")
                            return
                        }
                        
                        let mutuals = mutualSnapshot?.documents.compactMap { document in
                            try? WaffleUser(from: document)
                        } ?? []
                        
                        mutualFriends = mutuals
                    }
                }
            }
        }
    }
    
    private func loadTotalLikes() {
        let db = Firestore.firestore()
        
        db.collection("videos").whereField("authorId", isEqualTo: user.uid).getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoadingLikes = false
                
                if let error = error {
                    print("❌ Error loading user videos for likes: \(error.localizedDescription)")
                    return
                }
                
                let totalLikes = snapshot?.documents.reduce(0) { total, document in
                    let likeCount = document.data()["likeCount"] as? Int ?? 0
                    return total + likeCount
                } ?? 0
                
                self.totalLikes = totalLikes
            }
        }
    }
    
    private func checkFollowStatus() {
        guard let currentUserId = authManager.currentUser?.uid else { 
            isLoadingFollowStatus = false
            return 
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(currentUserId).collection("following").document(user.uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error checking follow status: \(error.localizedDescription)")
                    self.isLoadingFollowStatus = false
                    return
                }
                
                self.isFollowing = document?.exists ?? false
                self.isLoadingFollowStatus = false
            }
        }
    }
    
    
    private func followUser(_ user: WaffleUser) {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // Add to current user's following collection
        db.collection("users").document(currentUserId).collection("following").document(user.uid).setData([
            "followedAt": Timestamp(date: Date()),
            "userId": user.uid
        ]) { error in
            if let error = error {
                print("❌ Error following user: \(error.localizedDescription)")
                return
            }
            
            // Add to target user's followers collection
            db.collection("users").document(user.uid).collection("followers").document(currentUserId).setData([
                "followedAt": Timestamp(date: Date()),
                "userId": currentUserId
            ]) { error in
                if let error = error {
                    print("❌ Error adding follower: \(error.localizedDescription)")
                    return
                }
                
                // Update friend counts
                self.updateFriendCounts(currentUserId: currentUserId, targetUserId: user.uid, isFollowing: true)

                // Create follow notification
                NotificationManager.createFollowNotification(
                    recipientId: user.uid,
                    senderId: currentUserId,
                    senderName: self.authManager.currentUserProfile?.displayName ?? "Someone",
                    senderProfileImageURL: self.authManager.currentUserProfile?.profileImageURL
                )
            }
        }
        
        // Update UI immediately
        DispatchQueue.main.async {
            self.isFollowing = true
        }
    }
    
    private func unfollowUser(_ user: WaffleUser) {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // Remove from current user's following collection
        db.collection("users").document(currentUserId).collection("following").document(user.uid).delete { error in
            if let error = error {
                print("❌ Error unfollowing user: \(error.localizedDescription)")
                return
            }
            
            // Remove from target user's followers collection
            db.collection("users").document(user.uid).collection("followers").document(currentUserId).delete { error in
                if let error = error {
                    print("❌ Error removing follower: \(error.localizedDescription)")
                    return
                }
                
                // Update friend counts
                self.updateFriendCounts(currentUserId: currentUserId, targetUserId: user.uid, isFollowing: false)
            }
        }
        
        // Update UI immediately
        DispatchQueue.main.async {
            self.isFollowing = false
        }
    }
    
    private func updateFriendCounts(currentUserId: String, targetUserId: String, isFollowing: Bool) {
        let db = Firestore.firestore()
        let increment = isFollowing ? 1 : -1
        
        // Update current user's friends count
        db.collection("users").document(currentUserId).updateData([
            "friendsCount": FieldValue.increment(Int64(increment))
        ])
        
        // Refresh the auth manager's user profile
        authManager.refreshUserProfile()
    }
}