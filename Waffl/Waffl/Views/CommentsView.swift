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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text("Comments")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Button("Cancel") {
                        // Do nothing
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
                                CommentRowView(comment: comment, onLike: {
                                    toggleCommentLike(comment)
                                })
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
                            .textFieldStyle(RoundedBorderTextFieldStyle())
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
                    print("✅ Loaded \(loadedComments.count) comments")
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
                }
            }
        }
    }
    
    private func toggleCommentLike(_ comment: Comment) {
        guard let currentUserId = authManager.currentUser?.uid else { return }
        
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
                // Unlike
                let updatedLikedBy = likedBy.filter { $0 != currentUserId }
                transaction.updateData([
                    "likedBy": updatedLikedBy,
                    "likesCount": max(0, currentLikes - 1),
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: commentRef)
            } else {
                // Like
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
                } else {
                    print("✅ Comment like toggled successfully!")
                    self.loadComments() // Refresh to update like status
                }
            }
        }
    }
}

struct CommentRowView: View {
    let comment: Comment
    let onLike: () -> Void
    
    var body: some View {
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
                
                // Comment content
                Text(comment.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Like button
                HStack {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                            
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    CommentsView(videoId: "sample-video-id")
        .environmentObject(AuthManager())
}