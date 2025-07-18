//
//  AuthManager.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var currentUserProfile: WaffleUser?
    @Published var isLoading = false
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    self?.fetchUserProfile(uid: user.uid)
                } else {
                    self?.currentUserProfile = nil
                }
            }
        }
    }
    
    private func fetchUserProfile(uid: String) {
        isLoading = true
        
        db.collection("users").document(uid).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching user profile: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("User profile document does not exist")
                    return
                }
                
                do {
                    let userProfile = try WaffleUser(from: document)
                    self?.currentUserProfile = userProfile
                } catch {
                    print("Error parsing user profile: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUserProfile = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Profile Management
    
    func updateUserProfile(firstName: String, lastName: String, completion: @escaping (Error?) -> Void) {
        guard let uid = currentUser?.uid else {
            completion(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]))
            return
        }
        
        let updateData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "displayName": "\(firstName) \(lastName)",
            "updatedAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).updateData(updateData) { [weak self] error in
            if error == nil {
                // Refresh the user profile
                self?.fetchUserProfile(uid: uid)
            }
            completion(error)
        }
    }
    
    func incrementVideosUploaded() {
        guard let uid = currentUser?.uid else { return }
        
        db.collection("users").document(uid).updateData([
            "videosUploaded": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ]) { [weak self] error in
            if error == nil {
                // Refresh the user profile
                self?.fetchUserProfile(uid: uid)
            }
        }
    }
    
    func incrementWeeksParticipated() {
        guard let uid = currentUser?.uid else { return }
        
        db.collection("users").document(uid).updateData([
            "weeksParticipated": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ]) { [weak self] error in
            if error == nil {
                // Refresh the user profile
                self?.fetchUserProfile(uid: uid)
            }
        }
    }
    
    func updateFriendsCount(count: Int) {
        guard let uid = currentUser?.uid else { return }
        
        db.collection("users").document(uid).updateData([
            "friendsCount": count,
            "updatedAt": Timestamp(date: Date())
        ]) { [weak self] error in
            if error == nil {
                // Refresh the user profile
                self?.fetchUserProfile(uid: uid)
            }
        }
    }
}
