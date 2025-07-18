//
//  CreateVideoView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct CreateVideoView: View {
    @State private var isRecording = false
    @State private var recordedVideoURL: URL?
    @State private var showingCamera = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Your Waffle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Share a 1-minute video of your week")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Recording status
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        if let videoURL = recordedVideoURL {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if recordedVideoURL != nil {
                        Text("Video recorded successfully!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text("No video recorded yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if recordedVideoURL == nil {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Record Video")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button(action: {
                                // TODO: Upload video to Firebase
                                uploadVideo()
                            }) {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up")
                                    Text("Share Video")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.orange)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                recordedVideoURL = nil
                            }) {
                                Text("Record Again")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(videoURL: $recordedVideoURL)
        }
    }
    
    private func uploadVideo() {
        // TODO: Implement video upload to Firebase
        print("Uploading video...")
    }
}
