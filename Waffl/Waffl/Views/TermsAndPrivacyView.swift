//
//  TermsAndPrivacyView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/18/25.
//

import SwiftUI

struct TermsAndPrivacyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our")
                .font(.caption)
                .foregroundColor(Color.primary)
            
            HStack(spacing: 4) {
                Button("Terms of Service") {
                }
                .font(.caption)
                .foregroundColor(.orange)
                
                Text("and")
                    .font(.caption)
                    .foregroundColor(Color.primary)
                
                Button("Privacy Policy") {
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }
}
