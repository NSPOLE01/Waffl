//
//  HomeScreenView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct HomeScreenView: View {
    @State private var selectedTab = 1 // Start with "Browse Videos" tab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Browse Videos Tab
            BrowseVideosView()
                .tabItem {
                    Image(systemName: "video.fill")
                    Text("Browse Videos")
                }
                .tag(1)
            
            // Create Video Tab
            CreateVideoView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Video")
                }
                .tag(2)
            
            // Account Tab
            AccountView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Account")
                }
                .tag(3)
        }
        .accentColor(.orange)
        .navigationBarHidden(true)
    }
}
