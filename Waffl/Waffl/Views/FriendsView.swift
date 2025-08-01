//
//  FriendsView.swift
//  Waffl
//
//  Created by Claude on 8/1/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum ConfirmationAction {
    case follow(WaffleUser)
    case unfollow(WaffleUser)
    
    var title: String {
        switch self {
        case .follow(let user):
            return "Follow \(user.firstName)?"
        case .unfollow(let user):
            return "Unfollow \(user.firstName)?"
        }
    }
    
    var message: String {
        switch self {
        case .follow(let user):
            return "Do you want to follow \(user.displayName)?"
        case .unfollow(let user):
            return "Do you want to unfollow \(user.displayName)? You can always follow them again later."
        }
    }
    
    var actionText: String {
        switch self {
        case .follow:
            return "Follow"
        case .unfollow:
            return "Unfollow"
        }
    }
    
    var user: WaffleUser {
        switch self {
        case .follow(let user), .unfollow(let user):
            return user
        }
    }
}

struct FriendsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var followingFriends: [WaffleUser] = []
    @State private var discoverUsers: [WaffleUser] = []
    @State private var isLoadingFollowing = true
    @State private var isLoadingDiscover = true
    @State private var searchText = ""
    @State private var showingConfirmation = false
    @State private var confirmationAction: ConfirmationAction?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Following Friends Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Following")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(followingFriends.count)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if isLoadingFollowing {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.2)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if followingFriends.isEmpty {
                            EmptyFriendsView()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(followingFriends) { friend in
                                    FriendRowView(user: friend, isFollowing: true) {
                                        confirmationAction = .unfollow(friend)
                                        showingConfirmation = true
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Discover Friends Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Discover Friends")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: refreshDiscoverUsers) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search users...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        
                        if isLoadingDiscover {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.2)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredDiscoverUsers) { user in
                                    FriendRowView(user: user, isFollowing: false) {
                                        confirmationAction = .follow(user)
                                        showingConfirmation = true
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            loadFollowingFriends()
            loadDiscoverUsers()
        }
        .overlay(
            confirmationModalOverlay
        )
    }
    
    var filteredDiscoverUsers: [WaffleUser] {
        if searchText.isEmpty {
            return discoverUsers
        } else {
            return discoverUsers.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.firstName.localizedCaseInsensitiveContains(searchText) ||
                user.lastName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
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
    
    private func performConfirmationAction(_ action: ConfirmationAction) {
        switch action {
        case .follow(let user):
            followUser(user)
        case .unfollow(let user):
            unfollowUser(user)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadFollowingFriends() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        isLoadingFollowing = true
        
        let db = Firestore.firestore()
        
        // Get the user's following list
        db.collection("users").document(currentUserId).collection("following").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error loading following: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFollowing = false
                }
                return
            }
            
            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self.isLoadingFollowing = false
                }
                return
            }
            
            // Get the user IDs of followed users
            let followingIds = documents.compactMap { $0.documentID }
            
            if followingIds.isEmpty {
                DispatchQueue.main.async {
                    self.followingFriends = []
                    self.isLoadingFollowing = false
                }
                return
            }
            
            // Fetch the actual user documents
            db.collection("users").whereField("uid", in: followingIds).getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading friend details: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingFollowing = false
                    }
                    return
                }
                
                let friends = snapshot?.documents.compactMap { document in
                    try? WaffleUser(from: document)
                } ?? []
                
                DispatchQueue.main.async {
                    self.followingFriends = friends
                    self.isLoadingFollowing = false
                }
            }
        }
    }
    
    private func loadDiscoverUsers() {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
        isLoadingDiscover = true
        
        let db = Firestore.firestore()
        
        // First, get the current user's following list
        db.collection("users").document(currentUserId).collection("following").getDocuments { snapshot, error in
            let followingIds = snapshot?.documents.compactMap { $0.documentID } ?? []
            var excludeIds = followingIds
            excludeIds.append(currentUserId) // Also exclude the current user
            
            // Get users that are not being followed and not the current user
            db.collection("users").limit(to: 20).getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading discover users: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingDiscover = false
                    }
                    return
                }
                
                let allUsers = snapshot?.documents.compactMap { document in
                    try? WaffleUser(from: document)
                } ?? []
                
                // Filter out users that are already being followed or are the current user
                let discoverableUsers = allUsers.filter { user in
                    !excludeIds.contains(user.uid)
                }
                
                DispatchQueue.main.async {
                    self.discoverUsers = discoverableUsers
                    self.isLoadingDiscover = false
                }
            }
        }
    }
    
    private func refreshDiscoverUsers() {
        loadDiscoverUsers()
    }
    
    // MARK: - Friend Actions
    
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
            // Move user from discover to following
            if let index = self.discoverUsers.firstIndex(where: { $0.uid == user.uid }) {
                let followedUser = self.discoverUsers.remove(at: index)
                self.followingFriends.append(followedUser)
            }
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
            // Move user from following to discover
            if let index = self.followingFriends.firstIndex(where: { $0.uid == user.uid }) {
                let unfollowedUser = self.followingFriends.remove(at: index)
                self.discoverUsers.insert(unfollowedUser, at: 0)
            }
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

// MARK: - Supporting Views

struct FriendRowView: View {
    let user: WaffleUser
    let isFollowing: Bool
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
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

struct EmptyFriendsView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No Friends Yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Start following friends to see them here")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 32)
    }
}