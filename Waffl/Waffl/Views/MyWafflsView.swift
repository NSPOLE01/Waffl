//
//  MyWafflsView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct MyWafflsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var videos: [WaffleVideo] = []
    @State private var isLoadingVideos = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("My Waffls")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Your weekly moments and memories")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Video count
                            VStack {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(videos.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Quick stats
                        HStack(spacing: 20) {
                            StatCard(title: "Videos", value: "\(videos.count)", icon: "video.fill")
                            StatCard(title: "This Week", value: "\(getThisWeekVideosCount())", icon: "calendar")
                            StatCard(title: "Total Views", value: "0", icon: "eye.fill")
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Videos Section
                    if isLoadingVideos {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading your videos...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else if videos.isEmpty {
                        EmptyMyVideosView()
                    } else {
                        ForEach(videos) { video in
                            MyWafflVideoCard(video: video, currentUserProfile: authManager.currentUserProfile)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadMyVideos()
            }
            .refreshable {
                loadMyVideos()
            }
        }
    }
    
    private func loadMyVideos() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found")
            isLoadingVideos = false
            return
        }
        
        print("🔍 Loading videos for user ID: \(currentUserId)")
        isLoadingVideos = true
        let db = Firestore.firestore()
        
        // First, let's check all videos in the collection to debug
        db.collection("videos").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                print("📊 Total videos in collection: \(documents.count)")
                for doc in documents {
                    let data = doc.data()
                    if let authorId = data["authorId"] as? String {
                        print("📹 Video \(doc.documentID): authorId = \(authorId)")
                        if authorId == currentUserId {
                            print("✅ This video matches current user!")
                        }
                    }
                }
            }
        }
        
        // Get only videos uploaded by the current user
        db.collection("videos")
            .whereField("authorId", isEqualTo: currentUserId)
            .order(by: "uploadDate", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoadingVideos = false
                    
                    if let error = error {
                        print("❌ Error loading my videos: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents returned from query")
                        self.videos = []
                        return
                    }
                    
                    print("📊 Query returned \(documents.count) documents")
                    
                    let loadedVideos = documents.compactMap { document in
                        print("🔍 Processing document: \(document.documentID)")
                        do {
                            let video = try WaffleVideo(from: document, currentUserId: currentUserId)
                            print("✅ Successfully parsed video: \(video.id)")
                            return video
                        } catch {
                            print("❌ Failed to parse video \(document.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    // Videos are already sorted by the server-side query
                    self.videos = loadedVideos
                    print("✅ Final result: Loaded \(loadedVideos.count) videos for current user")
                }
            }
    }
    
    private func getThisWeekVideosCount() -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        return videos.filter { video in
            video.uploadDate >= startOfWeek
        }.count
    }
}

// MARK: - Empty My Videos View
struct EmptyMyVideosView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No videos yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Start creating your weekly moments!\nTap 'Create Video' to get started.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - My Waffle Video Card (with current profile picture)
struct MyWafflVideoCard: View {
    let video: WaffleVideo
    let currentUserProfile: WaffleUser?
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var viewCount: Int
    @State private var showingLikesList = false
    @EnvironmentObject var authManager: AuthManager
    
    init(video: WaffleVideo, currentUserProfile: WaffleUser?) {
        self.video = video
        self.currentUserProfile = currentUserProfile
        self._isLiked = State(initialValue: video.isLikedByCurrentUser)
        self._likeCount = State(initialValue: video.likeCount)
        self._viewCount = State(initialValue: video.viewCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video thumbnail/placeholder
            Button(action: {
                incrementViewCount()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("\(video.duration)s")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Video info with current profile picture
            HStack {
                // Use current user's profile picture instead of stored video avatar
                if let profileImageURL = currentUserProfile?.profileImageURL, !profileImageURL.isEmpty {
                    AuthorAvatarView(avatarString: profileImageURL)
                } else {
                    AuthorAvatarView(avatarString: "person.circle.fill")
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Posted \(video.uploadDate.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Views and likes section
                HStack(spacing: 12) {
                    // View count with eye icon
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("\(viewCount)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Like section with separate buttons
                    HStack(spacing: 8) {
                        // Heart button for liking
                        Button(action: {
                            toggleLike()
                        }) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isLiked ? .red : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Like count button for showing who liked
                        if likeCount > 0 {
                            Button(action: {
                                showingLikesList = true
                            }) {
                                Text("\(likeCount)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingLikesList) {
            LikesListView(videoId: video.id)
        }
    }
    
    private func toggleLike() {
        // Optimistic UI update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        // Update Firebase
        updateLikeInFirebase()
    }
    
    private func incrementViewCount() {
        // Optimistic UI update
        viewCount += 1
        
        // Update Firebase
        updateViewCountInFirebase()
    }
    
    private func updateViewCountInFirebase() {
        let db = Firestore.firestore()
        let videoRef = db.collection("videos").document(video.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let videoDocument: DocumentSnapshot
            do {
                try videoDocument = transaction.getDocument(videoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = videoDocument.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve video data"])
                errorPointer?.pointee = error
                return nil
            }
            
            let currentViewCount = data["viewCount"] as? Int ?? 0
            
            transaction.updateData([
                "viewCount": currentViewCount + 1
            ], forDocument: videoRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ Transaction failed for video view count: \(error)")
                
                // Revert optimistic UI update on failure
                DispatchQueue.main.async {
                    self.viewCount -= 1
                }
            } else {
                print("✅ View count updated successfully for video: \(self.video.id)")
            }
        }
    }
    
    private func updateLikeInFirebase() {
        guard let currentUserId = authManager.currentUser?.uid else {
            print("❌ No current user found for like operation")
            return
        }
        
        let db = Firestore.firestore()
        let videoRef = db.collection("videos").document(video.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let videoDocument: DocumentSnapshot
            do {
                try videoDocument = transaction.getDocument(videoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = videoDocument.data() else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve video data"])
                errorPointer?.pointee = error
                return nil
            }
            
            var likes = data["likes"] as? [String] ?? []
            let currentLikeCount = data["likeCount"] as? Int ?? 0
            
            if self.isLiked {
                // Add like
                if !likes.contains(currentUserId) {
                    likes.append(currentUserId)
                    transaction.updateData([
                        "likes": likes,
                        "likeCount": currentLikeCount + 1
                    ], forDocument: videoRef)
                }
            } else {
                // Remove like
                if let index = likes.firstIndex(of: currentUserId) {
                    likes.remove(at: index)
                    transaction.updateData([
                        "likes": likes,
                        "likeCount": max(0, currentLikeCount - 1)
                    ], forDocument: videoRef)
                }
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ Transaction failed for video like: \(error)")
                
                // Revert optimistic UI update on failure
                DispatchQueue.main.async {
                    self.isLiked.toggle()
                    self.likeCount += self.isLiked ? 1 : -1
                }
            } else {
                print("✅ Like status updated successfully for video: \(self.video.id)")
            }
        }
    }
}