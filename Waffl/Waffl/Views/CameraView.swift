//
//  CameraView.swift
//  Waffl
//
//  Created by Nikhil Polepalli on 7/17/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var videoURL: URL?
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Camera controls overlay
            VStack {
                // Top controls
                HStack {
                    Button("Cancel") {
                        cameraManager.stopSession()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Camera flip button
                    Button(action: {
                        cameraManager.flipCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                Spacer()
                
                // Recording status
                if cameraManager.isRecording {
                    VStack(spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("REC")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Text(formatTime(cameraManager.recordingDuration))
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Spacer()
                    
                    // Record button
                    Button(action: {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording { url in
                                videoURL = url
                                presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            cameraManager.startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 70, height: 70)
                            
                            if cameraManager.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                            } else {
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .disabled(cameraManager.recordingDuration >= 60) // 60 second limit
                    
                    Spacer()
                }
                .padding(.bottom, 40)
            }
            
            // Permission denied overlay
            if cameraManager.permissionDenied {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Camera Access Required")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Please enable camera access in Settings to record videos")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Open Settings") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .onAppear {
            cameraManager.requestPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: Double = 0
    @Published var permissionDenied = false
    @Published var sessionConfigured = false
    
    var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var recordingTimer: Timer?
    private var outputURL: URL?
    private var completionHandler: ((URL?) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        }
    }
    
    private func setupCamera() {
        DispatchQueue.main.async {
            self.permissionDenied = false
        }
        
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("📱 Running on simulator - camera functionality will be mocked")
        return
        #endif
        
        // Setup camera on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            // Add video input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ No camera available")
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
            } catch {
                print("❌ Error setting up camera input: \(error)")
                return
            }
            
            // Add audio input
            if let microphone = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: microphone)
                    if session.canAddInput(audioInput) {
                        session.addInput(audioInput)
                    }
                } catch {
                    print("❌ Error setting up audio input: \(error)")
                }
            }
            
            // Add movie output
            let output = AVCaptureMovieFileOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            // Update properties on main queue
            DispatchQueue.main.async {
                self.captureSession = session
                self.currentCamera = camera
                self.movieOutput = output
                self.sessionConfigured = true
            }
            
            // Start the session
            session.startRunning()
            print("✅ Camera session started successfully")
        }
    }
    
    func startRecording() {
        #if targetEnvironment(simulator)
        // Mock recording for simulator
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingDuration = 0
            self.startTimer()
        }
        return
        #endif
        
        guard let movieOutput = movieOutput else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("recorded_video_\(Date().timeIntervalSince1970).mov")
        self.outputURL = outputURL
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingDuration = 0
            self.startTimer()
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        #if targetEnvironment(simulator)
        // Mock recording completion for simulator
        self.stopTimer()
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
            // Create a mock file URL for simulator testing
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let mockURL = documentsPath.appendingPathComponent("mock_video_\(Date().timeIntervalSince1970).mov")
            
            // Create an empty file for testing
            try? Data().write(to: mockURL)
            
            completion(mockURL)
        }
        return
        #endif
        
        self.completionHandler = completion
        movieOutput?.stopRecording()
        stopTimer()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func flipCamera() {
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        // Remove current video input
        let currentVideoInput = captureSession.inputs.first { input in
            (input as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
        }
        
        if let videoInput = currentVideoInput {
            captureSession.removeInput(videoInput)
        }
        
        // Add new camera input
        let newPosition: AVCaptureDevice.Position = currentCamera?.position == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newVideoInput) {
                captureSession.addInput(newVideoInput)
                currentCamera = newCamera
            }
        } catch {
            print("❌ Error flipping camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    func stopSession() {
        captureSession?.stopRunning()
        stopTimer()
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.recordingDuration += 0.1
                
                // Auto-stop at 60 seconds
                if self.recordingDuration >= 60 {
                    self.stopRecording { url in
                        self.completionHandler?(url)
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("❌ Recording error: \(error)")
            DispatchQueue.main.async {
                self.completionHandler?(nil)
            }
        } else {
            print("✅ Video saved to: \(outputFileURL)")
            DispatchQueue.main.async {
                self.completionHandler?(outputFileURL)
            }
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
        }
    }
}

// MARK: - Camera Preview  
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black
        
        #if targetEnvironment(simulator)
        // Show mock camera preview on simulator
        let mockLabel = UILabel()
        mockLabel.text = "📱 Simulator Camera Preview\n\nCamera functionality works\non physical devices only"
        mockLabel.textColor = UIColor.white
        mockLabel.textAlignment = .center
        mockLabel.numberOfLines = 0
        mockLabel.font = UIFont.systemFont(ofSize: 16)
        mockLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mockLabel)
        
        NSLayoutConstraint.activate([
            mockLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mockLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mockLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            mockLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        #else
        // Real camera preview on device - will be added when session is ready
        setupPreviewLayer(for: view)
        #endif
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        #if !targetEnvironment(simulator)
        // Update preview layer when camera session becomes available
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        } else if cameraManager.sessionConfigured {
            setupPreviewLayer(for: uiView)
        }
        #endif
    }
    
    #if !targetEnvironment(simulator)
    private func setupPreviewLayer(for view: UIView) {
        guard let captureSession = cameraManager.captureSession else {
            // Session not ready yet, will be called again in updateUIView
            return
        }
        
        // Remove existing preview layer if any
        view.layer.sublayers?.removeAll(where: { $0 is AVCaptureVideoPreviewLayer })
        
        // Add new preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        print("✅ Camera preview layer added")
    }
    #endif
}