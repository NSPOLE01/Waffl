//
//  EditProfileView.swift
//  Waffl
//
//  Created by Claude on 7/31/25.
//

import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var showingSuccessToast = false
    @State private var showingErrorToast = false
    @State private var toastMessage = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    
    var hasChanges: Bool {
        let currentFirstName = authManager.currentUserProfile?.firstName ?? ""
        let currentLastName = authManager.currentUserProfile?.lastName ?? ""
        return firstName != currentFirstName || lastName != currentLastName || selectedPhotoData != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Profile Photo Section
                        VStack(spacing: 16) {
                            Text("Profile Photo")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                showingActionSheet = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    if let selectedPhotoData = selectedPhotoData,
                                       let uiImage = UIImage(data: selectedPhotoData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else if let profileImageURL = authManager.currentUserProfile?.profileImageURL,
                                              !profileImageURL.isEmpty {
                                        AsyncImage(url: URL(string: profileImageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 120)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 60))
                                                .foregroundColor(.orange)
                                        }
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    // Camera overlay
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Circle()
                                                .fill(Color.orange)
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Image(systemName: "camera.fill")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white)
                                                )
                                                .offset(x: -8, y: -8)
                                        }
                                    }
                                }
                            }
                            
                            Text("Tap to change photo")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        // Name Fields Section
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your first name", text: $firstName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your last name", text: $lastName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }
                        }
                        
                        // Confirm Changes Button
                        if hasChanges {
                            Button(action: saveChanges) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Confirm Changes")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                            .opacity(isLoading ? 0.6 : 1.0)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                
                // Toast Messages
                VStack {
                    if showingSuccessToast || showingErrorToast {
                        HStack {
                            Image(systemName: showingSuccessToast ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(showingSuccessToast ? .green : .red)
                            
                            Text(toastMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .padding(.top, 10)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedPhotoData = data
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Select Profile Photo"),
                buttons: [
                    .default(Text("Photo Library")) {
                        showingImagePicker = true
                    },
                    .default(Text("Camera")) {
                        showingCamera = true
                    },
                    .cancel()
                ]
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    selectedPhotoData = imageData
                }
            }
        }
    }
    
    private func loadCurrentProfile() {
        if let profile = authManager.currentUserProfile {
            firstName = profile.firstName
            lastName = profile.lastName
        }
    }
    
    private func saveChanges() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        // If there's a new photo, upload it first
        if let photoData = selectedPhotoData {
            uploadProfilePhoto(photoData: photoData, userId: currentUser.uid) { [self] photoURL in
                updateUserProfile(userId: currentUser.uid, profileImageURL: photoURL)
            }
        } else {
            // No new photo, just update name
            updateUserProfile(userId: currentUser.uid, profileImageURL: nil)
        }
    }
    
    private func uploadProfilePhoto(photoData: Data, userId: String, completion: @escaping (String?) -> Void) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let profileImageRef = storageRef.child("profile_images/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        profileImageRef.putData(photoData, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ Error uploading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            profileImageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    completion(url?.absoluteString)
                }
            }
        }
    }
    
    private func updateUserProfile(userId: String, profileImageURL: String?) {
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "displayName": "\(firstName) \(lastName)",
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let profileImageURL = profileImageURL {
            updateData["profileImageURL"] = profileImageURL
        }
        
        db.collection("users").document(userId).updateData(updateData) { [self] error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    toastMessage = "Failed to update profile"
                    showingErrorToast = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingErrorToast = false
                    }
                } else {
                    toastMessage = "Changes saved successfully!"
                    showingSuccessToast = true
                    
                    // Refresh the auth manager's user profile
                    authManager.refreshUserProfile()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingSuccessToast = false
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ImagePicker for Camera
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImageSelected(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImageSelected(originalImage)
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}