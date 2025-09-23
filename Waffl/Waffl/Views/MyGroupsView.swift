//
//  MyGroupsView.swift
//  Waffl
//
//  Created by Claude on 8/30/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

// MARK: - Group Data Model
struct WaffleGroup: Identifiable, Codable {
    let id: String
    let name: String
    let createdBy: String
    let createdAt: Date
    let members: [String] // Array of user IDs
    let memberCount: Int

    init(id: String = UUID().uuidString, name: String, createdBy: String, members: [String]) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.createdAt = Date()
        self.members = members
        self.memberCount = members.count
    }

    init(from document: DocumentSnapshot) throws {
        let data = document.data()

        guard let name = data?["name"] as? String,
              let createdBy = data?["createdBy"] as? String,
              let createdAtTimestamp = data?["createdAt"] as? Timestamp,
              let members = data?["members"] as? [String] else {
            throw NSError(domain: "GroupModelError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid group data"])
        }

        self.id = document.documentID
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAtTimestamp.dateValue()
        self.members = members
        self.memberCount = data?["memberCount"] as? Int ?? members.count
    }

    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "members": members,
            "memberCount": memberCount
        ]
    }
}

struct MyGroupsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingCreateGroup = false
    @State private var groups: [WaffleGroup] = []
    @State private var isLoadingGroups = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("My Groups")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Groups you're part of")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Groups content
                if isLoadingGroups {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your groups...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if groups.isEmpty {
                    Spacer()
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple.opacity(0.6))

                        Text("No Groups Yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Join or create groups to see them here")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            showingCreateGroup = true
                        }) {
                            Text("Create Group")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .cornerRadius(25)
                        }
                        .padding(.top, 20)
                    }
                    Spacer()
                } else {
                    // Groups list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(groups) { group in
                                GroupRowView(group: group)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    // Create Group button when groups exist
                    Button(action: {
                        showingCreateGroup = true
                    }) {
                        Text("Create New Group")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingCreateGroup) {
            CreateGroupView(onGroupCreated: {
                loadGroups() // Refresh groups when a new group is created
            })
        }
        .onAppear {
            loadGroups()
        }
        .refreshable {
            loadGroups()
        }
    }

    private func loadGroups() {
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoadingGroups = false
            return
        }

        isLoadingGroups = true
        let db = Firestore.firestore()

        // Get groups where the current user is a member
        db.collection("groups")
            .whereField("members", arrayContains: currentUserId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingGroups = false

                    if let error = error {
                        print("❌ Error loading groups: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("⚠️ No groups found")
                        self.groups = []
                        return
                    }

                    let loadedGroups = documents.compactMap { document in
                        try? WaffleGroup(from: document)
                    }

                    self.groups = loadedGroups
                    print("✅ Loaded \(loadedGroups.count) groups")
                }
            }
    }
}

// MARK: - Group Row View
struct GroupRowView: View {
    let group: WaffleGroup

    var body: some View {
        HStack(spacing: 16) {
            // Group Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
            }

            // Group Info
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("Created \(group.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CreateGroupView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    let onGroupCreated: (() -> Void)?
    
    @State private var friends: [WaffleUser] = []
    @State private var selectedFriends: Set<String> = []
    @State private var isLoadingFriends = true
    @State private var groupName = ""
    @State private var isCreatingGroup = false

    private var isButtonEnabled: Bool {
        !selectedFriends.isEmpty && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Text("Create Group")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Placeholder for balance
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            
            VStack(spacing: 20) {

                // Group name input - moved below instructions
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name this Group", text: $groupName)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .font(.system(size: 16))
                }
                .padding(.top, 24)
                
                // Friends list
                if isLoadingFriends {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your friends...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Friends Yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Add friends first to create groups")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(friends) { friend in
                                FriendSelectionRow(
                                    friend: friend,
                                    isSelected: selectedFriends.contains(friend.uid)
                                ) {
                                    toggleFriendSelection(friend.uid)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                    }
                }
                
                Spacer()

                // Create Group Button
                Button(action: {
                    createGroup()
                }) {
                    HStack {
                        if isCreatingGroup {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Creating...")
                        } else {
                            Text("Create Group")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isButtonEnabled ? Color.purple : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isButtonEnabled || isCreatingGroup)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadFriends()
        }
    }

    private func createGroup() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found")
            return
        }

        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedFriends.isEmpty else {
            print("❌ Group name or selected friends is empty")
            return
        }

        isCreatingGroup = true

        // Include the current user in the members array
        var allMembers = Array(selectedFriends)
        allMembers.append(currentUserId)

        let group = WaffleGroup(
            name: trimmedName,
            createdBy: currentUserId,
            members: allMembers
        )

        let db = Firestore.firestore()

        db.collection("groups").document(group.id).setData(group.toDictionary()) { error in
            DispatchQueue.main.async {
                self.isCreatingGroup = false

                if let error = error {
                    print("❌ Error creating group: \(error.localizedDescription)")
                } else {
                    print("✅ Group created successfully!")
                    self.onGroupCreated?()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func toggleFriendSelection(_ friendId: String) {
        if selectedFriends.contains(friendId) {
            selectedFriends.remove(friendId)
            print("🔍 Removed friend: \(friendId). Selected count: \(selectedFriends.count)")
        } else {
            selectedFriends.insert(friendId)
            print("🔍 Added friend: \(friendId). Selected count: \(selectedFriends.count)")
        }
        print("🔍 Button enabled: \(isButtonEnabled)")
    }
    
    private func loadFriends() {
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoadingFriends = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Get the user's following list
        db.collection("users").document(currentUserId).collection("following").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error loading following: \(error.localizedDescription)")
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
            
            let followingIds = documents.compactMap { $0.documentID }
            
            if followingIds.isEmpty {
                DispatchQueue.main.async {
                    self.friends = []
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
                
                DispatchQueue.main.async {
                    self.friends = friends
                    self.isLoadingFriends = false
                }
            }
        }
    }
}

struct FriendSelectionRow: View {
    let friend: WaffleUser
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator - moved further left
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.gray, lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                }

                // Profile Picture
                AsyncImage(url: URL(string: friend.profileImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                        )
                }

                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
