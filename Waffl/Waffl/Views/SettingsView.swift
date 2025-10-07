//
//  SettingsView.swift
//  Waffl
//
//  Created by Claude on 10/6/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeactivateAlert = false
    @State private var showingDeleteAlert = false
    @State private var isDeactivating = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    // Notification Settings
    @State private var likesNotifications = true
    @State private var commentsNotifications = true
    @State private var friendRequestsNotifications = true

    // Privacy Settings
    @State private var videosVisibleToAll = true
    @State private var acceptFriendRequestsFromAll = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Notifications Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notifications")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            SettingsToggleRow(
                                title: "Likes",
                                subtitle: "Get notified when someone likes your videos",
                                isOn: $likesNotifications
                            )

                            SettingsToggleRow(
                                title: "Comments",
                                subtitle: "Get notified when someone comments on your videos",
                                isOn: $commentsNotifications
                            )

                            SettingsToggleRow(
                                title: "Friend Requests",
                                subtitle: "Get notified when you receive friend requests",
                                isOn: $friendRequestsNotifications
                            )
                        }
                    }

                    // Privacy Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            SettingsToggleRow(
                                title: "Public Videos",
                                subtitle: "Allow anyone to see your videos",
                                isOn: $videosVisibleToAll
                            )

                            SettingsToggleRow(
                                title: "Accept All Friend Requests",
                                subtitle: "Automatically accept friend requests from anyone",
                                isOn: $acceptFriendRequestsFromAll
                            )
                        }
                    }

                    // Account Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Account")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            SettingsActionRow(
                                title: "Change Password",
                                icon: "key.fill",
                                color: .blue
                            ) {
                                // TODO: Implement change password
                            }

                            SettingsActionRow(
                                title: "Deactivate Account",
                                icon: "pause.circle.fill",
                                color: .orange
                            ) {
                                showingDeactivateAlert = true
                            }
                        }
                    }

                    // Legal Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Legal")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            SettingsActionRow(
                                title: "Terms of Service",
                                icon: "doc.text.fill",
                                color: .gray
                            ) {
                                // TODO: Open Terms of Service
                            }

                            SettingsActionRow(
                                title: "Privacy Policy",
                                icon: "hand.raised.fill",
                                color: .gray
                            ) {
                                // TODO: Open Privacy Policy
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .alert("Deactivate Account", isPresented: $showingDeactivateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Deactivate", role: .destructive) {
                deactivateAccount()
            }
        } message: {
            Text("This will permanently delete all your data including videos, likes, comments, and profile information. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay(
            Group {
                if isDeactivating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Deactivating account...")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(24)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        )
    }

    private func deactivateAccount() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No user found"
            showingErrorAlert = true
            return
        }

        isDeactivating = true
        let db = Firestore.firestore()
        let storage = Storage.storage()
        let userId = currentUser.uid

        // Delete user data in sequence
        deleteUserVideos(userId: userId, db: db, storage: storage) { [self] success in
            if success {
                deleteUserProfile(userId: userId, db: db) { [self] success in
                    if success {
                        deleteUserAccount(user: currentUser)
                    } else {
                        DispatchQueue.main.async {
                            self.isDeactivating = false
                            self.errorMessage = "Failed to delete profile data"
                            self.showingErrorAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isDeactivating = false
                    self.errorMessage = "Failed to delete video data"
                    self.showingErrorAlert = true
                }
            }
        }
    }

    private func deleteUserVideos(userId: String, db: Firestore, storage: Storage, completion: @escaping (Bool) -> Void) {
        // Get all user videos
        db.collection("videos").whereField("authorId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error getting user videos: \(error)")
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true) // No videos to delete
                return
            }

            let group = DispatchGroup()
            var hasErrors = false

            // Delete each video and its storage file
            for document in documents {
                group.enter()

                let videoData = document.data()
                if let videoURL = videoData["videoURL"] as? String {
                    // Delete from storage
                    storage.reference(forURL: videoURL).delete { error in
                        if let error = error {
                            print("❌ Error deleting video file: \(error)")
                            hasErrors = true
                        }

                        // Delete from firestore
                        document.reference.delete { error in
                            if let error = error {
                                print("❌ Error deleting video document: \(error)")
                                hasErrors = true
                            }
                            group.leave()
                        }
                    }
                } else {
                    // Just delete from firestore if no storage URL
                    document.reference.delete { error in
                        if let error = error {
                            print("❌ Error deleting video document: \(error)")
                            hasErrors = true
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                completion(!hasErrors)
            }
        }
    }

    private func deleteUserProfile(userId: String, db: Firestore, completion: @escaping (Bool) -> Void) {
        // Delete user profile and related data
        let batch = db.batch()

        // Delete user document
        let userRef = db.collection("users").document(userId)
        batch.deleteDocument(userRef)

        batch.commit { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting user profile: \(error)")
                    completion(false)
                } else {
                    print("✅ User profile deleted successfully")
                    completion(true)
                }
            }
        }
    }

    private func deleteUserAccount(user: User) {
        user.delete { error in
            DispatchQueue.main.async {
                self.isDeactivating = false

                if let error = error {
                    print("❌ Error deleting user account: \(error)")
                    self.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                } else {
                    print("✅ User account deleted successfully")
                    // Sign out and dismiss
                    self.authManager.signOut()
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Settings Row Components
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(.purple)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SettingsActionRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}