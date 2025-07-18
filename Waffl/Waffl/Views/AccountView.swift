//
//  AccountView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingSignOut = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Picture
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        if let profileImageURL = authManager.currentUserProfile?.profileImageURL,
                           !profileImageURL.isEmpty {
                            // TODO: Load profile image from URL
                            AsyncImage(url: URL(string: profileImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(authManager.currentUserProfile?.displayName ?? "Loading...")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(authManager.currentUserProfile?.email ?? "")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)
                
                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("\(authManager.currentUserProfile?.friendsCount ?? 0)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Friends")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("\(authManager.currentUserProfile?.videosUploaded ?? 0)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Videos")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("\(authManager.currentUserProfile?.weeksParticipated ?? 0)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Weeks")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Menu Options
                VStack(spacing: 16) {
                    AccountMenuButton(title: "Edit Profile", icon: "person.circle") {
                        // TODO: Navigate to edit profile
                    }
                    
                    AccountMenuButton(title: "Friends", icon: "person.2") {
                        // TODO: Navigate to friends list
                    }
                    
                    AccountMenuButton(title: "Settings", icon: "gear") {
                        // TODO: Navigate to settings
                    }
                    
                    AccountMenuButton(title: "Help & Support", icon: "questionmark.circle") {
                        // TODO: Navigate to help
                    }
                    
                    Button(action: {
                        showingSignOut = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                            
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .alert("Sign Out", isPresented: $showingSignOut) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func signOut() {
        authManager.signOut()
    }
}
