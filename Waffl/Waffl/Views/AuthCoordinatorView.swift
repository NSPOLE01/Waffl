//
//  AuthCoordinatorView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/14/25.
//

import SwiftUI

enum AuthenticationState {
    case signIn
    case signUp
}

struct AuthCoordinatorView: View {
    @State private var authState: AuthenticationState
    @Environment(\.presentationMode) var presentationMode
    
    init(initialState: AuthenticationState = .signIn) {
        self._authState = State(initialValue: initialState)
    }
    
    var body: some View {
        ZStack {
            switch authState {
            case .signIn:
                SignInView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ))
                    .onReceive(NotificationCenter.default.publisher(for: .navigateToSignUp)) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            authState = .signUp
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .dismissAuth)) { _ in
                        presentationMode.wrappedValue.dismiss()
                    }
                
            case .signUp:
                SignUpView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .onReceive(NotificationCenter.default.publisher(for: .navigateToSignIn)) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            authState = .signIn
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .dismissAuth)) { _ in
                        presentationMode.wrappedValue.dismiss()
                    }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Notifications for navigation
extension Notification.Name {
    static let navigateToSignIn = Notification.Name("navigateToSignIn")
    static let navigateToSignUp = Notification.Name("navigateToSignUp")
    static let dismissAuth = Notification.Name("dismissAuth")
}
