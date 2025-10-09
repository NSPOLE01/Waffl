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
    print("🚀 App launching...")
    FirebaseApp.configure()

    // Check if notifications are enabled
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("📱 Current notification settings: \(settings.authorizationStatus.rawValue)")
      print("📱 Alert setting: \(settings.alertSetting.rawValue)")
      print("📱 Badge setting: \(settings.badgeSetting.rawValue)")
      print("📱 Sound setting: \(settings.soundSetting.rawValue)")
    }

    // Initialize push notification manager
    _ = PushNotificationManager.shared

    return true
  }

  // Handle successful registration for remote notifications
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("✅ Successfully registered for remote notifications")

    // Pass device token to Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken

    // Now that APNS token is set, refresh FCM token
    PushNotificationManager.shared.refreshFCMToken()
  }

  // Handle failed registration for remote notifications
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
    print("❌ Error details: \(error.localizedDescription)")

    // Try to get more specific error information
    if let nsError = error as NSError? {
      print("❌ Error domain: \(nsError.domain)")
      print("❌ Error code: \(nsError.code)")
      print("❌ Error userInfo: \(nsError.userInfo)")
    }
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
