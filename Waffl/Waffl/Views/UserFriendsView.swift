//
//  UserFriendsView.swift
//  Waffl
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct UserFriendsView: View {
    let user: WaffleUser
    @EnvironmentObject var authManager: AuthManager
    
    @State private var userFriends: [WaffleUser] = []
    @State private var isLoadingFriends = true
    @State private var showingConfirmation = false
    @State private var confirmationAction: ConfirmationAction?
    @State private var myFollowingStatus: [String: Bool] = [:]
    @State private var isFollowingThisUser = false
    @State private var isCheckingFollowStatus = true
    
    var body: some View {
        VStack(spacing: 20) {
            if isCheckingFollowStatus {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            } else if !isFollowingThisUser {
                // Restricted access view
                VStack(spacing: 20) {
                    Image(systemName: "lock.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        Text("Friends List Private")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Follow \(user.firstName) to see who they're following")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 60)
            } else if isLoadingFriends {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading \(user.firstName)'s friends...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            } else if userFriends.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("\(user.firstName) has no friends yet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("When they follow people, you'll see them here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(userFriends) { friend in
                            UserFriendRowView(
                                user: friend,
                                isFollowing: myFollowingStatus[friend.uid] ?? false
                            ) {
                                if myFollowingStatus[friend.uid] == true {
                                    confirmationAction = .unfollow(friend)
                                } else {
                                    confirmationAction = .follow(friend)
                                }
                                showingConfirmation = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            
            Spacer()
        }
        .navigationTitle("\(user.firstName)'s Friends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkIfFollowingUser()
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
    
    private func checkIfFollowingUser() {
        guard let currentUserId = authManager.currentUser?.uid else { 
            isCheckingFollowStatus = false
            return 
        }
        
        // Don't need to check if viewing own friends
        if currentUserId == user.uid {
            isFollowingThisUser = true
            isCheckingFollowStatus = false
            loadUserFriends()
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(currentUserId).collection("following").document(user.uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error checking follow status: \(error.localizedDescription)")
                    self.isFollowingThisUser = false
                } else {
                    self.isFollowingThisUser = document?.exists ?? false
                }
                
                self.isCheckingFollowStatus = false
                
                // Load friends if following
                if self.isFollowingThisUser {
                    self.loadUserFriends()
                }
            }
        }
    }
    
    private func loadUserFriends() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        isLoadingFriends = true
        let db = Firestore.firestore()
        
        // Get the user's following list
        db.collection("users").document(user.uid).collection("following").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error loading user's friends: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFriends = false
                }
                return
            }
            
            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self.isLoadingFriends = false
                }
                return
            }
            
            // Get the user IDs of their friends
            let followingIds = documents.compactMap { $0.documentID }
            
            if followingIds.isEmpty {
                DispatchQueue.main.async {
                    self.userFriends = []
                    self.isLoadingFriends = false
                }
                return
            }
            
            // Fetch the actual user documents
            db.collection("users").whereField("uid", in: followingIds).getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading friend details: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingFriends = false
                    }
                    return
                }
                
                let friends = snapshot?.documents.compactMap { document in
                    try? WaffleUser(from: document)
                } ?? []
                
                // Now check which of these friends I'm following
                self.checkMyFollowingStatus(for: friends, currentUserId: currentUserId) {
                    DispatchQueue.main.async {
                        self.userFriends = friends
                        self.isLoadingFriends = false
                    }
                }
            }
        }
    }
    
    private func checkMyFollowingStatus(for friends: [WaffleUser], currentUserId: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        
        for friend in friends {
            dispatchGroup.enter()
            db.collection("users").document(currentUserId).collection("following").document(friend.uid).getDocument { document, error in
                DispatchQueue.main.async {
                    self.myFollowingStatus[friend.uid] = document?.exists ?? false
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion()
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
            self.myFollowingStatus[user.uid] = true
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
            self.myFollowingStatus[user.uid] = false
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

struct UserFriendRowView: View {
    let user: WaffleUser
    let isFollowing: Bool
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture and User Info - NavigationLink area
            NavigationLink(destination: UserProfileView(user: user)) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: user.profileImageURL)) { image in
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
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .semibold))
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
            Button(action: onAction) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFollowing ? .orange : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.orange.opacity(0.1) : Color.orange)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange, lineWidth: isFollowing ? 1 : 0)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}