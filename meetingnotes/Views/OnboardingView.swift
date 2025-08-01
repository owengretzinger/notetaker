import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var apiKey = ""
    @State private var hasAcceptedTerms = false
    @State private var micPermissionGranted = false
    @State private var systemAudioPermissionGranted = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    // Add AudioRecordingPermission instance
    @State private var audioRecordingPermission = AudioRecordingPermission()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Content area
                ScrollView {
                    VStack(spacing: 32) {
                        // Permissions Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Required Permissions")
                                .font(.title2)
                                .fontWeight(.semibold)
                        
                            VStack(spacing: 12) {
                                PermissionRow(
                                    title: "Microphone Access",
                                    description: "Required to transcribe what you say in meetings",
                                    isGranted: micPermissionGranted,
                                    action: requestMicrophonePermission
                                )
                                
                                PermissionRow(
                                    title: "System Audio Recording",
                                    description: "Required to transcribe what others say in meetings",
                                    isGranted: systemAudioPermissionGranted,
                                    action: requestSystemAudioPermission
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // API Key Section
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OpenAI API Key")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Uses gpt-4o-mini-transcribe and gpt-4.1. Typical cost is ~$0.20/hour. Your Mac communicates directly with OpenAI.")
                                    .font(.body)
                                .foregroundColor(.secondary)
                            }
                            
                            Button("Get API Key from OpenAI") {
                                if let url = URL(string: "https://platform.openai.com/api-keys") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            
                            SecureField("OpenAI API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Stored locally and encrypted in Keychain.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Terms Section
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Terms and Privacy")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Of note, I am tracking a few basic anonymous metrics (installs, opens, meetings created) using PostHog, because I'm trying to gauge interest in the app. Everything is completely anonymous (feel free to check the source code). If you have any concerns, please reach out and we can find a solution.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Button("Privacy Policy") {
                                    if let url = URL(string: "https://meetingnotes.owengretzinger.com/privacy") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.link)
                                
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                Button("Terms of Service") {
                                    if let url = URL(string: "https://meetingnotes.owengretzinger.com/terms") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.link)
                                
                                Spacer()
                            }
                            
                            HStack {
                                Button(action: { hasAcceptedTerms.toggle() }) {
                                    Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(hasAcceptedTerms ? .blue : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                Text("I have read and agree to the Terms of Service and Privacy Policy")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }

                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Spacer()
                            Button("Get Started") {
                                // Complete onboarding
                                settingsViewModel.settings.openAIKey = apiKey
                                settingsViewModel.completeOnboarding()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!canProceed)
                        }
                    }
                    .padding(.vertical, 30)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text(permissionAlertMessage)
        }
        .onAppear {
            checkPermissions()
            settingsViewModel.loadAPIKey()
            apiKey = settingsViewModel.settings.openAIKey
            hasAcceptedTerms = settingsViewModel.settings.hasAcceptedTerms
        }
        .onChange(of: audioRecordingPermission.status) { oldValue, newValue in
            // Update permission status when it changes
            systemAudioPermissionGranted = (newValue == .authorized)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Re-check permissions when app becomes active (in case they were changed in System Settings)
            checkPermissions()
        }
    }
    
    private var canProceed: Bool {
        return micPermissionGranted && 
               systemAudioPermissionGranted && 
               !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               hasAcceptedTerms
    }
    
    private func checkPermissions() {
        // Check microphone permission using AVCaptureDevice (macOS compatible)
        micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        
        // Check system audio recording permission
        systemAudioPermissionGranted = (audioRecordingPermission.status == .authorized)
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
                if !granted {
                    permissionAlertMessage = "Microphone access is required for recording meetings. Please enable it in System Preferences > Security & Privacy > Privacy > Microphone."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func requestSystemAudioPermission() {
        audioRecordingPermission.request()
        
        // Show alert if permission is denied after request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if audioRecordingPermission.status == .denied {
                permissionAlertMessage = "System audio recording access is required to capture what others say in meetings. Please enable 'meetingnotes' in System Preferences > Security & Privacy > Privacy > Microphone."
                showingPermissionAlert = true
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Button("Enable") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView(settingsViewModel: SettingsViewModel())
        .frame(width: 600, height: 700)
}