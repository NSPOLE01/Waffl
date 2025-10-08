//
//  NotificationsView.swift
//  Waffl
//
//  Created by Claude on 10/7/25.
//

import SwiftUI

struct NotificationsView: View {
    @StateObject private var notificationManager = NotificationManager()
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedTab: Int
    let onVideoSelected: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if notificationManager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading notifications...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notificationManager.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.purple.opacity(0.6))

                        Text("No Notifications")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("When someone likes, comments, or follows you, you'll see it here")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(notificationManager.notifications) { notification in
                                NotificationRow(
                                    notification: notification,
                                    onTap: {
                                        handleNotificationTap(notification)
                                    },
                                    onMarkAsRead: {
                                        notificationManager.markAsRead(notificationId: notification.id)
                                    }
                                )
                                .background(notification.isRead ? Color.clear : Color.purple.opacity(0.05))

                                if notification.id != notificationManager.notifications.last?.id {
                                    Divider()
                                        .padding(.leading, 80)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Notifications")
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    if notificationManager.hasUnreadNotifications() {
                        Button("Mark All Read") {
                            notificationManager.markAllAsRead()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                    }
                }
            }
        }
    }

    private func handleNotificationTap(_ notification: WaffleNotification) {
        // Mark as read if not already read
        if !notification.isRead {
            notificationManager.markAsRead(notificationId: notification.id)
        }

        // Handle navigation based on notification type
        switch notification.type {
        case .like, .comment:
            if let videoId = notification.videoId {
                // Dismiss notifications view
                presentationMode.wrappedValue.dismiss()
                // Navigate to video
                onVideoSelected(videoId)
            }
        case .follow:
            // For follow notifications, we could navigate to the user's profile
            // For now, just mark as read
            break
        }
    }
}

struct NotificationRow: View {
    let notification: WaffleNotification
    let onTap: () -> Void
    let onMarkAsRead: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Image
                AsyncImage(url: URL(string: notification.senderProfileImageURL ?? "")) { image in
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

                // Notification Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Notification Text
                        Text(buildNotificationText())
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Spacer()

                        // Time and unread indicator
                        HStack(spacing: 8) {
                            Text(notification.timeAgo)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            if !notification.isRead {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }

                    // Comment text if it's a comment notification
                    if notification.type == .comment, let commentText = notification.commentText {
                        Text("\"\(commentText)\"")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                }

                // Video Thumbnail for video-related notifications
                if notification.type == .like || notification.type == .comment {
                    if let thumbnailURL = notification.videoThumbnailURL {
                        AsyncImage(url: URL(string: thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !notification.isRead {
                Button("Mark Read") {
                    onMarkAsRead()
                }
                .tint(.purple)
            }
        }
    }

    private func buildNotificationText() -> AttributedString {
        var attributedString = AttributedString()

        // Sender name (bold)
        var senderName = AttributedString(notification.senderName)
        senderName.font = .system(size: 15, weight: .semibold)
        attributedString.append(senderName)

        // Action text
        let actionText = AttributedString(" \(notification.type.title)")
        attributedString.append(actionText)

        return attributedString
    }
}

