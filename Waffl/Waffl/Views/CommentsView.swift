//
//  CommentsView.swift
//  Waffl
//
//  Created by Claude Code on 2025-09-02.
//

import SwiftUI
import FirebaseFirestore

struct CommentsView: View {
    let videoId: String
    let onDismiss: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    @State private var optimisticLikes: [String: Bool] = [:]
    @State private var optimisticLikeCounts: [String: Int] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                        onDismiss?()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    
                    Spacer()
                    
                    Text("Comments")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Comments List
                if isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading comments...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                        
                        VStack(spacing: 8) {
                            Text("No comments yet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Be the first to leave a comment!")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(comments) { comment in
                                CommentRowView(
                                    comment: comment,
                                    onLike: {
                                        toggleCommentLike(comment)
                                    },
                                    onDelete: {
                                        deleteComment(comment)
                                    },
                                    currentUserId: authManager.currentUser?.uid,
                                    optimisticLiked: optimisticLikes[comment.id] ?? comment.isLikedByCurrentUser,
                                    optimisticLikeCount: optimisticLikeCounts[comment.id] ?? comment.likesCount
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
                
                // Comment Input
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        // User's profile picture
                        AsyncImage(url: URL(string: authManager.currentUserProfile?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.purple)
                                )
                        }
                        
                        // Text input
                        TextField("Add a comment...", text: $newCommentText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .disabled(isPostingComment)
                        
                        // Post button
                        Button(action: postComment) {
                            if isPostingComment {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .purple)
                            }
                        }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        isLoading = true
        let db = Firestore.firestore()
        
        guard let currentUserId = authManager.currentUser?.uid else {
            isLoading = false
            return
        }
        
        db.collection("comments")
            .whereField("videoId", isEqualTo: videoId)
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("❌ Error loading comments: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No comments found")
                        self.comments = []
                        return
                    }
                    
                    let loadedComments = documents.compactMap { document in
                        try? Comment(from: document, currentUserId: currentUserId)
                    }
                    
                    self.comments = loadedComments
                    self.optimisticLikes.removeAll()
                    self.optimisticLikeCounts.removeAll()
                }
            }
    }
    
    private func postComment() {
        guard let currentUser = authManager.currentUser,
              let userProfile = authManager.currentUserProfile else { return }
        
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isPostingComment = true
        let db = Firestore.firestore()
        
        let comment = Comment(
            videoId: videoId,
            authorId: currentUser.uid,
            authorName: userProfile.displayName,
            authorProfileImageURL: userProfile.profileImageURL,
            content: trimmedText
        )
        
        db.collection("comments").addDocument(data: comment.toDictionary()) { error in
            DispatchQueue.main.async {
                self.isPostingComment = false
                
                if let error = error {
                    print("❌ Error posting comment: \(error.localizedDescription)")
                } else {
                    print("✅ Comment posted successfully!")
                    self.newCommentText = ""
                    self.loadComments() // Refresh comments
                    self.updateVideoCommentCount(increment: true)

                    // Create notification for comment
                    self.createCommentNotification(commentText: trimmedText)
                }
            }
        }
    }
    
    private func toggleCommentLike(_ comment: Comment) {
        
        guard let currentUserId = authManager.currentUser?.uid else { 
            print("❌ No current user found")
            return 
        }
        
        // IMMEDIATE UI UPDATE: Set optimistic state first
        let currentLikeState = optimisticLikes[comment.id] ?? comment.isLikedByCurrentUser
        let newLikeState = !currentLikeState
        let currentLikeCount = optimisticLikeCounts[comment.id] ?? comment.likesCount
        let newLikeCount = newLikeState ? currentLikeCount + 1 : max(0, currentLikeCount - 1)

        DispatchQueue.main.async {
            self.optimisticLikes[comment.id] = newLikeState
            self.optimisticLikeCounts[comment.id] = newLikeCount
        }

        let db = Firestore.firestore()
        let commentRef = db.collection("comments").document(comment.id)
        
        db.runTransaction { transaction, errorPointer in
            let commentDocument: DocumentSnapshot
            do {
                try commentDocument = transaction.getDocument(commentRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = commentDocument.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to retrieve comment data"
                ])
                errorPointer?.pointee = error
                return nil
            }
            
            let likedBy = data["likedBy"] as? [String] ?? []
            let currentLikes = data["likesCount"] as? Int ?? 0
            
            if likedBy.contains(currentUserId) {
                let updatedLikedBy = likedBy.filter { $0 != currentUserId }
                transaction.updateData([
                    "likedBy": updatedLikedBy,
                    "likesCount": max(0, currentLikes - 1),
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: commentRef)
            } else {
                let updatedLikedBy = likedBy + [currentUserId]
                transaction.updateData([
                    "likedBy": updatedLikedBy,
                    "likesCount": currentLikes + 1,
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: commentRef)
            }
            
            return nil
        } completion: { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error toggling comment like: \(error.localizedDescription)")
                    // Revert optimistic state on error
                    self.optimisticLikes.removeValue(forKey: comment.id)
                    self.optimisticLikeCounts.removeValue(forKey: comment.id)
                    self.loadComments()
                } else {
                }
            }
        }
    }
    
    private func deleteComment(_ comment: Comment) {
        guard let currentUserId = authManager.currentUser?.uid,
              currentUserId == comment.authorId else {
            print("❌ User not authorized to delete this comment")
            return
        }
        
        let db = Firestore.firestore()
        let commentRef = db.collection("comments").document(comment.id)
        
        commentRef.delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting comment: \(error.localizedDescription)")
                } else {
                    print("✅ Comment deleted successfully!")
                    self.loadComments()
                    self.updateVideoCommentCount(increment: false)
                }
            }
        }
    }
    
    private func updateVideoCommentCount(increment: Bool) {
        let db = Firestore.firestore()
        let videosRef = db.collection("videos").document(videoId)
        
        db.runTransaction { transaction, errorPointer in
            let videoDocument: DocumentSnapshot
            do {
                try videoDocument = transaction.getDocument(videosRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let currentCount = videoDocument.data()?["commentCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            transaction.updateData([
                "commentCount": newCount
            ], forDocument: videosRef)
            
            return nil
        } completion: { _, error in
            if let error = error {
                print("❌ Error updating comment count: \(error.localizedDescription)")
            } else {
                print("✅ Comment count updated successfully!")
            }
        }
    }

    private func createCommentNotification(commentText: String) {
        guard let currentUser = authManager.currentUser,
              let userProfile = authManager.currentUserProfile else { return }

        let db = Firestore.firestore()

        // Fetch video information to get the author details
        db.collection("videos").document(videoId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching video for notification: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data(),
                  let videoAuthorId = data["authorId"] as? String else {
                print("❌ Video data not found for notification")
                return
            }

            NotificationManager.createCommentNotification(
                videoId: self.videoId,
                videoThumbnailURL: data["thumbnailURL"] as? String,
                commentText: commentText,
                recipientId: videoAuthorId,
                senderId: currentUser.uid,
                senderName: userProfile.displayName,
                senderProfileImageURL: userProfile.profileImageURL
            )
        }
    }
}

struct CommentRowView: View {
    let comment: Comment
    let onLike: () -> Void
    let onDelete: () -> Void
    let currentUserId: String?
    let optimisticLiked: Bool
    let optimisticLikeCount: Int
    
    @State private var dragOffset: CGFloat = 0
    @State private var showingDeleteConfirmation = false
    
    private var canDelete: Bool {
        return currentUserId == comment.authorId
    }
    
    var body: some View {
        ZStack {
            // Delete button background (revealed on swipe)
            if canDelete {
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
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .opacity(dragOffset < -50 ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: dragOffset)
            }
            
            // Main comment content
            HStack(alignment: .top, spacing: 12) {
                // Profile picture
                AsyncImage(url: URL(string: comment.authorProfileImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Author and time
                    HStack {
                        Text(comment.authorName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(comment.timeAgoString)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // Comment content and like button on same line
                    HStack(alignment: .top, spacing: 8) {
                        Text(comment.content)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: {
                            print("🔍 Like button tapped for comment: \(comment.id)")
                            onLike()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: optimisticLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundColor(optimisticLiked ? .red : .secondary)

                                if optimisticLikeCount > 0 {
                                    Text("\(optimisticLikeCount)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .background(Color(.systemBackground))
            .offset(x: dragOffset)
            .gesture(
                canDelete ? 
                DragGesture()
                    .onChanged { value in
                        let newOffset = min(0, value.translation.width)
                        dragOffset = max(newOffset, -80) 
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if dragOffset < -50 {
                                dragOffset = -70
                            } else {
                                dragOffset = 0
                            }
                        }
                    }
                : nil
            )
        }
        .alert("Delete Comment", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                withAnimation(.easeOut(duration: 0.3)) {
                    dragOffset = 0
                }
            }
            Button("Delete", role: .destructive) {
                onDelete()
                withAnimation(.easeOut(duration: 0.3)) {
                    dragOffset = 0
                }
            }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
    }
}

#Preview {
    CommentsView(videoId: "sample-video-id", onDismiss: nil)
        .environmentObject(AuthManager())
}
