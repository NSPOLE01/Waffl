//
//  WafflApp.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    // Initialize push notification manager
    _ = PushNotificationManager.shared

    return true
  }

  // Handle successful registration for remote notifications
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("✅ Successfully registered for remote notifications")

    // Pass device token to Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
  }

  // Handle failed registration for remote notifications
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
  }
}


@main
struct WafflApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
