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

// MARK: - Group Videos View
struct GroupVideosView: View {
    let group: WaffleGroup
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var videos: [WaffleVideo] = []
    @State private var isLoadingVideos = true
    @State private var showingGroupMembers = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    Text(group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Edit button
                    Button(action: {
                        showingGroupMembers = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Videos content
                if isLoadingVideos {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading this week's videos...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if videos.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.purple.opacity(0.6))

                        Text("No Videos This Week")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Group members haven't posted any waffls this week yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(videos) { video in
                                VideoCard(video: video)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadGroupVideos()
        }
        .refreshable {
            loadGroupVideos()
        }
        .fullScreenCover(isPresented: $showingGroupMembers) {
            GroupMembersView(group: group)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToAccountTab"))) { _ in
            // Dismiss this view when switching to Account tab
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func loadGroupVideos() {
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoadingVideos = false
            return
        }

        isLoadingVideos = true
        let db = Firestore.firestore()

        // Calculate start of current week
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()

        // Get videos from group members posted this week
        db.collection("videos")
            .whereField("authorId", in: group.members)
            .whereField("uploadDate", isGreaterThanOrEqualTo: Timestamp(date: startOfWeek))
            .order(by: "uploadDate", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingVideos = false

                    if let error = error {
                        print("❌ Error loading group videos: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("⚠️ No group videos found")
                        self.videos = []
                        return
                    }

                    let loadedVideos = documents.compactMap { document in
                        try? WaffleVideo(from: document, currentUserId: currentUserId)
                    }

                    self.videos = loadedVideos
                    print("✅ Loaded \(loadedVideos.count) group videos from this week")
                }
            }
    }
}

// MARK: - Group Members View
struct GroupMembersView: View {
    let group: WaffleGroup
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var members: [WaffleUser] = []
    @State private var isLoadingMembers = true
    @State private var isAccordionExpanded = false
    @State private var showingAddUsers = false
    @State private var showingLeaveConfirmation = false

    private var otherMembers: [WaffleUser] {
        guard let currentUserId = authManager.currentUser?.uid else { return members }
        return members.filter { $0.uid != currentUserId }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    Text(group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Add users button
                    Button(action: {
                        showingAddUsers = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 16) {
                        // Members Accordion
                        VStack(spacing: 0) {
                            // Accordion Header
                            HStack(spacing: 16) {
                                // Group icon
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.1))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: "person.3.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.purple)
                                }

                                // Title and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Group Members")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    if isLoadingMembers {
                                        Text("Loading...")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(otherMembers.count) other member\(otherMembers.count == 1 ? "" : "s")")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Chevron
                                Image(systemName: isAccordionExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isAccordionExpanded.toggle()
                                }
                            }

                            // Accordion Content
                            if isAccordionExpanded {
                                VStack(spacing: 8) {
                                    if isLoadingMembers {
                                        VStack(spacing: 16) {
                                            ProgressView()
                                                .scaleEffect(1.2)
                                            Text("Loading group members...")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 20)
                                    } else if otherMembers.isEmpty {
                                        VStack(spacing: 16) {
                                            Image(systemName: "person.2.slash")
                                                .font(.system(size: 40))
                                                .foregroundColor(.purple.opacity(0.6))

                                            Text("No Other Members")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)

                                            Text("You're the only member in this group")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 20)
                                    } else {
                                        ForEach(otherMembers) { member in
                                            GroupMemberRow(
                                                member: member,
                                                onDelete: {
                                                    removeMemberFromGroup(member)
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                .animation(.easeInOut(duration: 0.3), value: members.count)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        Spacer()

                        // Leave Group Button
                        Button(action: {
                            showingLeaveConfirmation = true
                        }) {
                            Text("Leave Group")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadGroupMembers()
        }
        .refreshable {
            loadGroupMembers()
        }
        .fullScreenCover(isPresented: $showingAddUsers) {
            AddUsersToGroupView(group: group) {
                loadGroupMembers() // Refresh members when users are added
            }
        }
        .alert("Leave Group", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                leaveGroup()
            }
        } message: {
            Text("Are you sure you want to leave \(group.name)? You won't be able to see group videos or rejoin unless someone adds you back.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToAccountTab"))) { _ in
            // Dismiss this view when switching to Account tab
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func leaveGroup() {
        guard let currentUserId = authManager.currentUser?.uid else { return }

        let db = Firestore.firestore()
        var updatedMembers = group.members
        if let memberIndex = updatedMembers.firstIndex(of: currentUserId) {
            updatedMembers.remove(at: memberIndex)

            db.collection("groups").document(group.id).updateData([
                "members": updatedMembers,
                "memberCount": updatedMembers.count
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error leaving group: \(error.localizedDescription)")
                    } else {
                        print("✅ Successfully left group")
                        // Dismiss this view and go back to groups list
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func removeMemberFromGroup(_ member: WaffleUser) {
        // Remove from local array first for immediate UI update
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members.remove(at: index)
        }

        // Update Firebase
        let db = Firestore.firestore()
        var updatedMembers = group.members
        if let memberIndex = updatedMembers.firstIndex(of: member.uid) {
            updatedMembers.remove(at: memberIndex)

            db.collection("groups").document(group.id).updateData([
                "members": updatedMembers,
                "memberCount": updatedMembers.count
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error removing member from group: \(error.localizedDescription)")
                        // Revert local change on error
                        self.members.append(member)
                    } else {
                        print("✅ Member removed from group successfully")
                    }
                }
            }
        }
    }

    private func loadGroupMembers() {
        isLoadingMembers = true
        let db = Firestore.firestore()

        // Get member details for all user IDs in the group
        db.collection("users")
            .whereField("uid", in: group.members)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingMembers = false

                    if let error = error {
                        print("❌ Error loading group members: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("⚠️ No group members found")
                        self.members = []
                        return
                    }

                    let loadedMembers = documents.compactMap { document in
                        try? WaffleUser(from: document)
                    }

                    self.members = loadedMembers
                    print("✅ Loaded \(loadedMembers.count) group members")
                }
            }
    }
}

// MARK: - Group Member Row
struct GroupMemberRow: View {
    let member: WaffleUser
    let onDelete: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            // Delete button background (revealed on swipe)
            HStack {
                Spacer()
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .opacity(dragOffset < -50 ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: dragOffset)

            // Main member content
            HStack(spacing: 16) {
                // Profile Picture
                AsyncImage(url: URL(string: member.profileImageURL)) { image in
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

                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow left swipe (negative translation)
                        let newOffset = min(0, value.translation.width)
                        dragOffset = max(newOffset, -80) // Limit swipe distance
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if dragOffset < -50 {
                                // Keep slightly open to show delete button
                                dragOffset = -70
                            } else {
                                // Snap back to original position
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .alert("Remove Member", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                withAnimation(.easeOut(duration: 0.3)) {
                    dragOffset = 0
                }
            }
            Button("Remove", role: .destructive) {
                onDelete()
                withAnimation(.easeOut(duration: 0.3)) {
                    dragOffset = 0
                }
            }
        } message: {
            Text("Are you sure you want to remove \(member.displayName) from this group?")
        }
    }
}

// MARK: - Add Users to Group View
struct AddUsersToGroupView: View {
    let group: WaffleGroup
    let onUsersAdded: () -> Void
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var availableUsers: [WaffleUser] = []
    @State private var selectedUsers: Set<String> = []
    @State private var isLoadingUsers = true
    @State private var isAddingUsers = false

    private var isButtonEnabled: Bool {
        !selectedUsers.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    Text("Add Members")
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
                    // Instructions
                    VStack(spacing: 8) {
                        Text("Select Friends")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Choose friends to add to \(group.name)")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Users list
                    if isLoadingUsers {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading your friends...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    } else if availableUsers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No Friends Available")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)

                            Text("All your friends are already in this group or you have no friends to add")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(availableUsers) { user in
                                    FriendSelectionRow(
                                        friend: user,
                                        isSelected: selectedUsers.contains(user.uid)
                                    ) {
                                        toggleUserSelection(user.uid)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                        }
                    }

                    Spacer()

                    // Add Members Button
                    Button(action: {
                        addSelectedUsersToGroup()
                    }) {
                        HStack {
                            if isAddingUsers {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Adding...")
                            } else {
                                Text("Add to Group")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isButtonEnabled ? Color.purple : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isButtonEnabled || isAddingUsers)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadAvailableUsers()
        }
    }

    private func toggleUserSelection(_ userId: String) {
        if selectedUsers.contains(userId) {
            selectedUsers.remove(userId)
        } else {
            selectedUsers.insert(userId)
        }
    }

    private func loadAvailableUsers() {
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoadingUsers = false
            return
        }

        isLoadingUsers = true
        let db = Firestore.firestore()

        // Get the user's following list
        db.collection("users").document(currentUserId).collection("following").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error loading following: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingUsers = false
                }
                return
            }

            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self.isLoadingUsers = false
                }
                return
            }

            let followingIds = documents.compactMap { $0.documentID }

            if followingIds.isEmpty {
                DispatchQueue.main.async {
                    self.availableUsers = []
                    self.isLoadingUsers = false
                }
                return
            }

            // Fetch the actual user documents
            db.collection("users").whereField("uid", in: followingIds).getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading friend details: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingUsers = false
                    }
                    return
                }

                let allFriends = snapshot?.documents.compactMap { document in
                    try? WaffleUser(from: document)
                } ?? []

                // Filter out users already in the group
                let availableUsers = allFriends.filter { friend in
                    !self.group.members.contains(friend.uid)
                }

                DispatchQueue.main.async {
                    self.availableUsers = availableUsers
                    self.isLoadingUsers = false
                }
            }
        }
    }

    private func addSelectedUsersToGroup() {
        guard !selectedUsers.isEmpty else { return }

        isAddingUsers = true
        let db = Firestore.firestore()

        // Add selected users to group members
        var updatedMembers = group.members
        updatedMembers.append(contentsOf: Array(selectedUsers))

        db.collection("groups").document(group.id).updateData([
            "members": updatedMembers,
            "memberCount": updatedMembers.count
        ]) { error in
            DispatchQueue.main.async {
                self.isAddingUsers = false

                if let error = error {
                    print("❌ Error adding users to group: \(error.localizedDescription)")
                } else {
                    print("✅ Users added to group successfully")
                    self.onUsersAdded()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Group Row View
struct GroupRowView: View {
    let group: WaffleGroup
    @State private var showingGroupVideos = false

    var body: some View {
        HStack(spacing: 16) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .onTapGesture {
            showingGroupVideos = true
        }
        .fullScreenCover(isPresented: $showingGroupVideos) {
            GroupVideosView(group: group)
        }
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
