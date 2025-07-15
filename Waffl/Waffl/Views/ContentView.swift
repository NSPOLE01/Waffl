// ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        OnboardingView()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        
        ContentView()
            .preferredColorScheme(.dark)
    }
}
