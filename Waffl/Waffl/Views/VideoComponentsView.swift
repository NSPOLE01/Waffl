//
//  VideoComponents.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

// MARK: - Video Card Component
struct VideoCard: View {
    let video: WaffleVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video thumbnail/placeholder
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
            
            // Video info
            HStack {
                Image(systemName: video.authorAvatar)
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(video.uploadDate, style: .relative)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !video.isWatched {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Empty Videos View
struct EmptyVideosView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No videos yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Be the first to share your week!\nTap the + button to get started.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Video Model
struct WaffleVideo: Identifiable {
    let id: String
    let authorName: String
    let authorAvatar: String
    let thumbnailURL: String?
    let duration: Int
    let uploadDate: Date
    let isWatched: Bool
}
