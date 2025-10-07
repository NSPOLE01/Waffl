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
    @State private var showingTimeUpAlert = false
    @State private var autoStoppedVideoURL: URL?
    @State private var sessionRetryCount = 0
    @State private var sessionRetryTimer: Timer?
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Camera controls overlay
            VStack {
                // Top controls
                HStack {
                    Button(action: {
                        cameraManager.stopSession()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
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
                            .foregroundColor(cameraManager.isRecording ? .gray : .white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    .disabled(cameraManager.isRecording)
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
                VStack(spacing: 16) {
                    if cameraManager.isRecording {
                        VStack(spacing: 8) {
                            HStack {
                                Text(formatTime(cameraManager.recordingDuration))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("1:00")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            
                            ProgressView(value: min(cameraManager.recordingDuration / 60.0, 1.0))
                                .progressViewStyle(LinearProgressViewStyle(tint: cameraManager.recordingDuration >= 60 ? .red : .purple))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    HStack {
                        Spacer()
                        
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
                    .foregroundColor(.purple)
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

            // Set up session monitoring for black screen detection
            sessionRetryTimer?.invalidate()
            sessionRetryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                // If session is configured but not running and not recording, try to restart
                if cameraManager.sessionConfigured &&
                   !cameraManager.isRecording &&
                   cameraManager.captureSession?.isRunning != true &&
                   sessionRetryCount < 3 {
                    print("🔄 Attempting to restart camera session (attempt \(sessionRetryCount + 1))")
                    sessionRetryCount += 1
                    cameraManager.restartSession()
                }
            }
        }
        .onDisappear {
            sessionRetryTimer?.invalidate()
            sessionRetryTimer = nil
            cameraManager.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Restart camera when app becomes active to fix black screen issues
            if !cameraManager.isRecording && cameraManager.sessionConfigured {
                cameraManager.restartSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Stop session when app goes to background
            if !cameraManager.isRecording {
                cameraManager.stopSession()
            }
        }
        .onReceive(cameraManager.$recordingDuration) { duration in
            // Show alert when 1 minute is reached
            if duration >= 60.0 && cameraManager.isRecording && !showingTimeUpAlert {
                showingTimeUpAlert = true
            }
        }
        .onReceive(cameraManager.$autoStoppedVideoURL) { url in
            // Set the video URL when auto-stop completes
            if let url = url {
                self.autoStoppedVideoURL = url
            }
        }
        .alert("Recording Complete", isPresented: $showingTimeUpAlert) {
            Button("OK") {
                // Use the auto-stopped video URL if available
                if let autoStoppedURL = autoStoppedVideoURL {
                    videoURL = autoStoppedURL
                    print("✅ Auto-stopped video set: \(autoStoppedURL)")
                } else if let manualURL = cameraManager.autoStoppedVideoURL {
                    videoURL = manualURL
                    print("✅ Manager auto-stopped video set: \(manualURL)")
                }
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("You've reached the 1-minute recording limit. Your video has been saved!")
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
    @Published var recordingComplete = false
    @Published var autoStoppedVideoURL: URL?

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
        DispatchQueue.main.async {
            self.sessionConfigured = true
        }
        return
        #endif

        // Setup camera on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // Stop any existing session first
            if let existingSession = self.captureSession {
                existingSession.stopRunning()
            }

            let session = AVCaptureSession()
            session.sessionPreset = .high

            session.beginConfiguration()

            // Add video input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ No camera available")
                session.commitConfiguration()
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                } else {
                    print("❌ Cannot add video input")
                    session.commitConfiguration()
                    return
                }
            } catch {
                print("❌ Error setting up camera input: \(error)")
                session.commitConfiguration()
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
            } else {
                print("❌ Cannot add movie output")
            }

            session.commitConfiguration()

            // Update properties on main queue before starting session
            DispatchQueue.main.async {
                self.captureSession = session
                self.currentCamera = camera
                self.movieOutput = output
                self.sessionConfigured = true

                // Start the session after properties are set
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                    print("✅ Camera session started successfully")
                }
            }
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
        #if targetEnvironment(simulator)
        print("📱 Camera flip not available on simulator")
        return
        #endif

        guard let captureSession = captureSession,
              let currentCamera = currentCamera,
              sessionConfigured,
              !isRecording else {
            print("❌ Camera session not ready for flip or recording in progress")
            return
        }

        // Perform camera flip on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Ensure session is running
            guard captureSession.isRunning else {
                print("❌ Session not running - cannot flip camera")
                return
            }

            captureSession.beginConfiguration()

            // Find and remove current video input
            var removedInput: AVCaptureDeviceInput?
            for input in captureSession.inputs {
                if let deviceInput = input as? AVCaptureDeviceInput,
                   deviceInput.device.hasMediaType(.video) {
                    captureSession.removeInput(deviceInput)
                    removedInput = deviceInput
                    break
                }
            }

            // Determine new camera position
            let newPosition: AVCaptureDevice.Position = currentCamera.position == .back ? .front : .back

            // Try to find new camera
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                print("❌ No camera available for position: \(newPosition)")

                // Restore original input if new camera not found
                if let originalInput = removedInput {
                    captureSession.addInput(originalInput)
                }
                captureSession.commitConfiguration()
                return
            }

            do {
                let newVideoInput = try AVCaptureDeviceInput(device: newCamera)

                if captureSession.canAddInput(newVideoInput) {
                    captureSession.addInput(newVideoInput)

                    // Update current camera on main queue
                    DispatchQueue.main.async {
                        self.currentCamera = newCamera
                    }

                    print("✅ Camera flipped to \(newPosition == .front ? "front" : "back")")
                } else {
                    print("❌ Cannot add new camera input")

                    // Restore original input if new one fails
                    if let originalInput = removedInput {
                        captureSession.addInput(originalInput)
                    }
                }
            } catch {
                print("❌ Error creating camera input for flip: \(error)")

                // Restore original input on error
                if let originalInput = removedInput {
                    captureSession.addInput(originalInput)
                }
            }

            captureSession.commitConfiguration()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
        stopTimer()
    }

    func restartSession() {
        guard let captureSession = captureSession else {
            setupCamera()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                DispatchQueue.global(qos: .userInitiated).async {
                    captureSession.startRunning()
                    print("✅ Camera session restarted")
                }
            }
        }
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.recordingDuration += 0.1
                
                // Auto-stop at 60 seconds
                if self.recordingDuration >= 60 {
                    // Stop the timer first to prevent multiple calls
                    self.stopTimer()

                    // Stop recording - this will trigger the delegate method
                    self.movieOutput?.stopRecording()

                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.recordingComplete = true
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
                if let completionHandler = self.completionHandler {
                    // Manual stop - use completion handler
                    completionHandler(outputFileURL)
                } else {
                    // Auto stop - set the URL for the UI to handle
                    self.autoStoppedVideoURL = outputFileURL
                }
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
            // Update frame
            previewLayer.frame = uiView.bounds

            // Check if session has changed (camera flip)
            if let currentSession = cameraManager.captureSession,
               previewLayer.session != currentSession {
                previewLayer.session = currentSession
                print("✅ Preview layer session updated")
            }
        } else if cameraManager.sessionConfigured && cameraManager.captureSession != nil {
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
