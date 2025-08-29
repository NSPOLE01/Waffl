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


struct FriendsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var followingFriends: [WaffleUser] = []
    @State private var discoverUsers: [WaffleUser] = []
    @State private var isLoadingFollowing = true
    @State private var isLoadingDiscover = true
    @State private var searchText = ""
    @State private var refreshTrigger = UUID()
    
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
                                            FriendRowView(user: friend, isFollowing: true, onTap: {
                                                // This will be handled by NavigationLink inside FriendRowView
                                            }) {
                                                unfollowUser(friend)
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
                                            .foregroundColor(.purple)
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
                                            FriendRowView(user: user, isFollowing: false, onTap: {
                                                // This will be handled by NavigationLink inside FriendRowView
                                            }) {
                                                followUser(user)
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
                            .foregroundColor(.purple)
                        }
                    }
        }
        .onAppear {
            loadFollowingFriends()
            loadDiscoverUsers()
        }
        .refreshable {
            loadFollowingFriends()
            loadDiscoverUsers()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFriendsView"))) { _ in
            refreshData()
        }
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
    
    private func refreshData() {
        loadFollowingFriends()
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
    let onTap: () -> Void
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture and User Info - NavigationLink area
            NavigationLink(destination: UserProfileView(user: user)
                .onDisappear {
                    // Refresh the parent view when returning from profile
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsView"), object: nil)
                    }
                }) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: user.profileImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.purple)
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
                    .foregroundColor(isFollowing ? .purple : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.purple.opacity(0.1) : Color.purple)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.purple, lineWidth: isFollowing ? 1 : 0)
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