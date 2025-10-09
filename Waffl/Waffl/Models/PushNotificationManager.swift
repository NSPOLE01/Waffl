//
//  PushNotificationManager.swift
//  Waffl
//
//  Created by Claude on 10/7/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions
import UserNotifications
import UIKit

class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    private let db = Firestore.firestore()

    override init() {
        super.init()
        setupNotifications()
    }

    private func setupNotifications() {
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self

        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self

        // Request permission for notifications
        requestNotificationPermission()

        // Setup auth state listener to handle token updates
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                print("🔐 User authenticated: \(user.uid)")
                // Don't immediately request FCM token - wait for APNS token first
                print("📱 Waiting for APNS token before requesting FCM token...")
            } else {
                print("🔐 User signed out")
            }
        }
    }

    func requestNotificationPermission() {
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("🚨 Running on iOS Simulator - Push notifications are not supported!")
        print("📱 To test push notifications, use a physical iOS device")
        return
        #endif

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { [weak self] granted, error in
            print("📱 Notification permission granted: \(granted)")

            if granted {
                print("📱 Attempting to register for remote notifications...")
                DispatchQueue.main.async {
                    print("📱 Calling UIApplication.shared.registerForRemoteNotifications()")
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📱 registerForRemoteNotifications() called - waiting for callback...")
                }

                // Permission granted - remote notification registration will trigger APNS token
                print("📱 Permission granted, will request FCM token after APNS token is received")
            }

            if let error = error {
                print("❌ Error requesting notification permission: \(error)")
            }
        }
    }

    // Public function to manually refresh FCM token
    func refreshFCMToken() {
        #if targetEnvironment(simulator)
        print("🚨 Cannot refresh FCM token on simulator - use a physical device")
        return
        #endif

        if let currentUser = Auth.auth().currentUser {
            print("🔄 Manually refreshing FCM token for: \(currentUser.uid)")
            updateFCMTokenForUser(userId: currentUser.uid)
        } else {
            print("❌ No authenticated user to refresh token for")
        }
    }

    private func updateFCMTokenForUser(userId: String) {
        print("🔄 Requesting FCM token for user: \(userId)")
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error fetching FCM registration token: \(error)")
                return
            }

            guard let token = token else {
                print("❌ FCM token is nil for user: \(userId)")
                return
            }

            print("✅ FCM registration token received for \(userId): \(String(token.prefix(20)))...")
            self?.saveFCMTokenToFirestore(userId: userId, token: token)
        }
    }

    private func saveFCMTokenToFirestore(userId: String, token: String) {
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "updatedAt": Timestamp(date: Date()),
            "platform": "iOS"
        ]

        db.collection("users").document(userId).setData(tokenData, merge: true) { error in
            if let error = error {
                print("❌ Error saving FCM token: \(error)")
            } else {
                print("✅ FCM token saved successfully for user: \(userId)")
            }
        }
    }

    // MARK: - Send Push Notifications

    static func sendPushNotification(
        to userId: String,
        title: String,
        body: String,
        data: [String: Any] = [:]
    ) {
        let db = Firestore.firestore()

        // Get user's FCM token
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error getting user for push notification: \(error)")
                return
            }

            guard let userData = snapshot?.data(),
                  let fcmToken = userData["fcmToken"] as? String else {
                print("❌ No FCM token found for user: \(userId)")
                return
            }

            // Create push notification payload
            let pushNotification: [String: Any] = [
                "to": fcmToken,
                "notification": [
                    "title": title,
                    "body": body,
                    "sound": "default",
                    "badge": 1
                ],
                "dataPayload": data,
                "priority": "high"
            ]

            // Send via Cloud Function (we'll create this)
            sendViaCloudFunction(payload: pushNotification)
        }
    }

    private static func sendViaCloudFunction(payload: [String: Any]) {
        // This will call a Firebase Cloud Function that sends the push notification
        // We'll create this cloud function separately
        let functions = Functions.functions()
        let sendNotification = functions.httpsCallable("sendPushNotification")

        sendNotification.call(payload) { result, error in
            if let error = error {
                print("❌ Error sending push notification: \(error)")
            } else {
                print("✅ Push notification sent successfully")
            }
        }
    }

    // MARK: - Notification Actions

    static func sendLikePushNotification(
        to userId: String,
        senderName: String,
        videoId: String
    ) {
        let title = "New Like"
        let body = "\(senderName) liked your video"
        let data: [String: Any] = [
            "type": "like",
            "videoId": videoId,
            "senderId": userId
        ]

        sendPushNotification(to: userId, title: title, body: body, data: data)
    }

    static func sendCommentPushNotification(
        to userId: String,
        senderName: String,
        commentText: String,
        videoId: String
    ) {
        let title = "New Comment"
        let body = "\(senderName): \(commentText)"
        let data: [String: Any] = [
            "type": "comment",
            "videoId": videoId,
            "senderId": userId,
            "commentText": commentText
        ]

        sendPushNotification(to: userId, title: title, body: body, data: data)
    }

    static func sendFollowPushNotification(
        to userId: String,
        senderName: String,
        senderId: String
    ) {
        let title = "New Follower"
        let body = "\(senderName) started following you"
        let data: [String: Any] = [
            "type": "follow",
            "senderId": senderId
        ]

        sendPushNotification(to: userId, title: title, body: body, data: data)
    }
}

// MARK: - MessagingDelegate
extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM registration token received automatically: \(String(describing: fcmToken?.prefix(20) ?? "nil"))...")

        // Update token for current user if logged in
        if let currentUser = Auth.auth().currentUser,
           let token = fcmToken {
            print("💾 Saving FCM token for user: \(currentUser.uid)")
            saveFCMTokenToFirestore(userId: currentUser.uid, token: token)
        } else {
            print("⚠️ No current user or FCM token to save")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap based on type
        if let type = userInfo["type"] as? String {
            switch type {
            case "like", "comment":
                if let videoId = userInfo["videoId"] as? String {
                    // Navigate to video
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToVideo"),
                        object: nil,
                        userInfo: ["videoId": videoId]
                    )
                }
            case "follow":
                if let senderId = userInfo["senderId"] as? String {
                    // Navigate to user profile
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToUserProfile"),
                        object: nil,
                        userInfo: ["userId": senderId]
                    )
                } else {
                    // Fallback to notifications
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToNotifications"),
                        object: nil
                    )
                }
            default:
                break
            }
        }

        completionHandler()
    }
}
