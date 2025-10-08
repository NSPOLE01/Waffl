//
//  NotificationManager.swift
//  Waffl
//
//  Created by Claude on 10/7/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

class NotificationManager: ObservableObject {
    @Published var notifications: [WaffleNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var notificationListener: ListenerRegistration?
    private var currentUserId: String?

    init() {
        setupAuthListener()
    }

    deinit {
        notificationListener?.remove()
    }

    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUserId = user?.uid
            if let userId = user?.uid {
                self?.startListeningForNotifications(userId: userId)
            } else {
                self?.stopListeningForNotifications()
            }
        }
    }

    private func startListeningForNotifications(userId: String) {
        isLoading = true

        notificationListener = db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error = error {
                        print("❌ Error listening for notifications: \(error.localizedDescription)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("⚠️ No notifications found")
                        return
                    }

                    var loadedNotifications: [WaffleNotification] = []

                    for document in documents {
                        do {
                            let notification = try WaffleNotification.fromFirestore(
                                data: document.data(),
                                id: document.documentID
                            )
                            loadedNotifications.append(notification)
                        } catch {
                            print("❌ Error parsing notification: \(error)")
                        }
                    }

                    self?.notifications = loadedNotifications
                    self?.updateUnreadCount()

                    print("✅ Loaded \(loadedNotifications.count) notifications")
                }
            }
    }

    private func stopListeningForNotifications() {
        notificationListener?.remove()
        notifications.removeAll()
        unreadCount = 0
    }

    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    // MARK: - Public Methods

    func markAsRead(notificationId: String) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationId }) else {
            return
        }

        // Update locally first for immediate UI response
        notifications[index].isRead = true
        updateUnreadCount()

        // Update in Firestore
        db.collection("notifications").document(notificationId).updateData([
            "isRead": true
        ]) { error in
            if let error = error {
                print("❌ Error marking notification as read: \(error.localizedDescription)")
                // Revert local change if Firestore update fails
                DispatchQueue.main.async {
                    self.notifications[index].isRead = false
                    self.updateUnreadCount()
                }
            } else {
                print("✅ Notification marked as read")
            }
        }
    }

    func markAllAsRead() {
        let unreadNotifications = notifications.filter { !$0.isRead }

        // Update locally first
        for i in 0..<notifications.count {
            notifications[i].isRead = true
        }
        updateUnreadCount()

        // Update in Firestore
        let batch = db.batch()
        for notification in unreadNotifications {
            let docRef = db.collection("notifications").document(notification.id)
            batch.updateData(["isRead": true], forDocument: docRef)
        }

        batch.commit { error in
            if let error = error {
                print("❌ Error marking all notifications as read: \(error.localizedDescription)")
            } else {
                print("✅ All notifications marked as read")
            }
        }
    }

    func deleteNotification(notificationId: String) {
        // Remove locally first
        notifications.removeAll { $0.id == notificationId }
        updateUnreadCount()

        // Delete from Firestore
        db.collection("notifications").document(notificationId).delete { error in
            if let error = error {
                print("❌ Error deleting notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification deleted")
            }
        }
    }

    // MARK: - Create Notifications

    static func createLikeNotification(
        videoId: String,
        videoThumbnailURL: String?,
        recipientId: String,
        senderId: String,
        senderName: String,
        senderProfileImageURL: String?
    ) {
        // Don't create notification if user likes their own video
        guard recipientId != senderId else { return }

        let notification = WaffleNotification(
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            senderProfileImageURL: senderProfileImageURL,
            type: .like,
            videoId: videoId,
            videoThumbnailURL: videoThumbnailURL
        )

        createNotification(notification)
    }

    static func createCommentNotification(
        videoId: String,
        videoThumbnailURL: String?,
        commentText: String,
        recipientId: String,
        senderId: String,
        senderName: String,
        senderProfileImageURL: String?
    ) {
        // Don't create notification if user comments on their own video
        guard recipientId != senderId else { return }

        let notification = WaffleNotification(
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            senderProfileImageURL: senderProfileImageURL,
            type: .comment,
            videoId: videoId,
            videoThumbnailURL: videoThumbnailURL,
            commentText: commentText
        )

        createNotification(notification)
    }

    static func createFollowNotification(
        recipientId: String,
        senderId: String,
        senderName: String,
        senderProfileImageURL: String?
    ) {
        // Don't create notification if user follows themselves
        guard recipientId != senderId else { return }

        let notification = WaffleNotification(
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            senderProfileImageURL: senderProfileImageURL,
            type: .follow
        )

        createNotification(notification)
    }

    private static func createNotification(_ notification: WaffleNotification) {
        let db = Firestore.firestore()

        db.collection("notifications").document(notification.id).setData(notification.toDictionary()) { error in
            if let error = error {
                print("❌ Error creating notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification created: \(notification.type.rawValue)")
            }
        }
    }

    // MARK: - Helper Methods

    func hasUnreadNotifications() -> Bool {
        return unreadCount > 0
    }

    func getNotificationCount() -> Int {
        return notifications.count
    }
}