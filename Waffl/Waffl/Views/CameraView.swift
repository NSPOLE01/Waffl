//
//  CameraView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI

struct CameraView: View {
    @Binding var videoURL: URL?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                Text("Camera functionality will be implemented here")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                
                Spacer()
                
                Button(action: {
                    // Mock recording completion
                    videoURL = URL(string: "mock://video.mp4")
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }
}
