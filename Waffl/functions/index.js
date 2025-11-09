const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to send push notifications via FCM
 * Called from iOS app when notifications need to be sent
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  console.log("📱 Push notification function called", {
    hasData: !!data,
    dataKeys: data ? Object.keys(data) : [],
  });

  try {
    const {to, notification, dataPayload, priority} = data;

    // Validate required fields
    if (!to || !notification) {
      console.error("❌ Missing required fields", {to: !!to, notification: !!notification});
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields: to, notification");
    }

    // Validate notification structure
    if (!notification.title || !notification.body) {
      console.error("❌ Invalid notification structure", {
        title: !!notification.title,
        body: !!notification.body,
      });
      throw new functions.https.HttpsError("invalid-argument", "Notification must have title and body");
    }

    console.log("📝 Validated notification", {
      title: notification.title,
      tokenPrefix: to.substring(0, 20),
    });

    // Convert all data values to strings (FCM requirement)
    const stringData = {};
    if (dataPayload) {
      Object.keys(dataPayload).forEach(key => {
        stringData[key] = String(dataPayload[key]);
      });
    }

    // Construct FCM message
    const message = {
      token: to,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: stringData,
      apns: {
        payload: {
          aps: {
            badge: notification.badge || 1,
            sound: notification.sound || "default",
            alert: {
              title: notification.title,
              body: notification.body,
            },
          },
        },
      },
    };

    console.log("🚀 Sending FCM message", {
      hasToken: !!message.token,
      hasNotification: !!message.notification,
      hasApns: !!message.apns,
    });

    // Send the message
    const response = await admin.messaging().send(message);

    console.log("✅ Successfully sent push notification", {
      messageId: response,
      tokenPrefix: to.substring(0, 20),
      title: notification.title,
    });

    return {
      success: true,
      messageId: response,
    };

  } catch (error) {
    console.error("❌ Error sending push notification", {
      errorMessage: error.message,
      errorCode: error.code,
      errorStack: error.stack,
      errorType: error.constructor.name,
    });

    // Re-throw HttpsError for proper client handling
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Convert other errors to HttpsError
    throw new functions.https.HttpsError("internal", "Failed to send push notification", error.message);
  }
});