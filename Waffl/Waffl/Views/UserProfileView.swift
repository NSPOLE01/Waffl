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
    @Environment(\.dismiss) private var dismiss
    
    @State private var isFollowing = false
    @State private var isLoadingFollowStatus = true
    @State private var showingConfirmation = false
    @State private var confirmationAction: ConfirmationAction?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Picture
                    AsyncImage(url: URL(string: user.profileImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                            )
                    }
                    
                    VStack(spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(user.email)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)
                
                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("\(user.friendsCount)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Friends")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("\(user.videosUploaded)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Videos")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("\(user.weeksParticipated)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Weeks")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Follow/Unfollow Button
                if isLoadingFollowStatus {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.vertical, 20)
                } else {
                    Button(action: {
                        if isFollowing {
                            confirmationAction = .unfollow(user)
                        } else {
                            confirmationAction = .follow(user)
                        }
                        showingConfirmation = true
                    }) {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isFollowing ? .orange : .white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(isFollowing ? Color.orange.opacity(0.1) : Color.orange)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.orange, lineWidth: isFollowing ? 1 : 0)
                            )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle(user.firstName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            checkFollowStatus()
        }
        .overlay(
            confirmationModalOverlay
        )
    }
    
    @ViewBuilder
    private var confirmationModalOverlay: some View {
        if showingConfirmation, let action = confirmationAction {
            ZStack {
                // Background overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingConfirmation = false
                        confirmationAction = nil
                    }
                
                // Modal content
                VStack(spacing: 0) {
                    // Header with title and close button
                    HStack {
                        Text(action.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingConfirmation = false
                            confirmationAction = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // User info
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: action.user.profileImageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.user.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(action.user.email)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // Message
                    Text(action.message)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Cancel button
                        Button(action: {
                            showingConfirmation = false
                            confirmationAction = nil
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        // Confirm action button
                        Button(action: {
                            performConfirmationAction(action)
                            showingConfirmation = false
                            confirmationAction = nil
                        }) {
                            Text(action.actionText)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 32)
            }
            .animation(.easeInOut(duration: 0.3), value: showingConfirmation)
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
    
    private func performConfirmationAction(_ action: ConfirmationAction) {
        switch action {
        case .follow(let user):
            followUser(user)
        case .unfollow(let user):
            unfollowUser(user)
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