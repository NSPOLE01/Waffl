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
                            VideoCard(video: video)
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
                            let video = try WaffleVideo(from: document)
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