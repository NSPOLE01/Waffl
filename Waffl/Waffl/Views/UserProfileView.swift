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
    
    @State private var isFollowing = false
    @State private var isLoadingFollowStatus = true
    @State private var totalLikes = 0
    @State private var isLoadingLikes = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Instagram-style Profile Header
            HStack(alignment: .top, spacing: 20) {
                // Profile Picture and Follow Button (left side)
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: user.profileImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 45))
                                    .foregroundColor(.orange)
                            )
                    }
                    
                    // Follow/Unfollow Button (bigger and more rounded)
                    if isLoadingFollowStatus {
                        ProgressView()
                            .scaleEffect(0.8)
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
                                .foregroundColor(isFollowing ? .orange : .white)
                                .frame(width: 120, height: 36)
                                .background(isFollowing ? Color.orange.opacity(0.1) : Color.orange)
                                .cornerRadius(18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.orange, lineWidth: isFollowing ? 1 : 0)
                                )
                        }
                    }
                }
                
                // Name, Stats and Content (right side)
                VStack(alignment: .leading, spacing: 16) {
                    // Name at the top
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    // Stats or locked state below name
                    if !isLoadingFollowStatus && !isFollowing {
                        // Locked Profile State
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 4) {
                                Text("Profile locked")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Follow to see content")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // Stats (only show when following or loading)
                        HStack(spacing: 24) {
                            VStack(spacing: 4) {
                                Text("\(user.videosUploaded)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Videos")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            NavigationLink(destination: UserFriendsView(user: user)) {
                                VStack(spacing: 4) {
                                    Text("\(user.friendsCount)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Friends")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            VStack(spacing: 4) {
                                if isLoadingLikes {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Text("\(totalLikes)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                Text("Likes")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
        }
        .navigationTitle(user.firstName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkFollowStatus()
            loadTotalLikes()
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