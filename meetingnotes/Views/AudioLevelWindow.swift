import SwiftUI

// MARK: - Dancing Audio Bars
struct DancingAudioBars: View {
    let micLevel: Float
    let systemLevel: Float
    
    var body: some View {
        VStack(spacing: 0) {
            // App logo
            Image("Icon32")
                .resizable()
                .frame(width: 32, height: 32)
            
            // Interleaved bars - alternating blue (mic) and orange (system)
            HStack(spacing: -2) {
                // Bar 1: Microphone (blue)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 6, height: getDancingBarHeight(index: 0, level: micLevel))
                    .animation(.easeInOut(duration: 0.1), value: micLevel)
                
                // Bar 2: System (orange)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: 6, height: getDancingBarHeight(index: 1, level: systemLevel))
                    .animation(.easeInOut(duration: 0.1).delay(0.03), value: systemLevel)
                
                // Bar 3: Microphone (blue)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 6, height: getDancingBarHeight(index: 2, level: micLevel))
                    .animation(.easeInOut(duration: 0.1).delay(0.06), value: micLevel)
                
                // Bar 4: System (orange)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: 6, height: getDancingBarHeight(index: 0, level: systemLevel))
                    .animation(.easeInOut(duration: 0.1).delay(0.09), value: systemLevel)
                
                // Bar 5: Microphone (blue)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 6, height: getDancingBarHeight(index: 1, level: micLevel))
                    .animation(.easeInOut(duration: 0.1).delay(0.12), value: micLevel)
                
                // Bar 6: System (orange)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: 6, height: getDancingBarHeight(index: 2, level: systemLevel))
                    .animation(.easeInOut(duration: 0.1).delay(0.15), value: systemLevel)
            }
            .frame(width: 32, height: 32)
        }
        .padding(0)
    }
    
    private func getDancingBarHeight(index: Int, level: Float) -> CGFloat {
        let baseHeight: CGFloat = 4 // Flat when no audio
        let maxHeight: CGFloat = 24 // Max dancing height
        
        if level > 0.03 { // Only dance when there's actual audio
            // Each bar responds to the same audio level but with different scaling
            // This creates a natural dancing effect as audio levels fluctuate
            let barVariation: [CGFloat] = [0.9, 1.0, 0.8] // Different responsiveness per bar
            let audioResponse = CGFloat(level) * maxHeight * barVariation[index % 3]
            return max(baseHeight, min(maxHeight, baseHeight + audioResponse))
        }
        
        return baseHeight
    }
}

// MARK: - Audio Level Window View
struct AudioLevelWindowView: View {
    @StateObject private var audioLevelManager = AudioLevelManager.shared
    
    var body: some View {
        let micLevel = audioLevelManager.isRecording ? audioLevelManager.micAudioLevel * 30 : 0
        let systemLevel = audioLevelManager.isRecording ? audioLevelManager.systemAudioLevel * 5 : 0
        return DancingAudioBars(
                micLevel: micLevel,
                systemLevel: systemLevel
            )
            .padding(2)
            .background(.regularMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.2), radius: 3)
    }
}

// MARK: - Audio Level Manager (Singleton to share data)
class AudioLevelManager: ObservableObject {
    static let shared = AudioLevelManager()
    
    @Published var micAudioLevel: Float = 0.0
    @Published var systemAudioLevel: Float = 0.0
    @Published var isRecording: Bool = false
    
    private init() {}
    
    func updateMicLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.micAudioLevel = level
        }
    }
    
    func updateSystemLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.systemAudioLevel = level
        }
    }
    
    func updateRecordingState(_ isRecording: Bool) {
        DispatchQueue.main.async {
            self.isRecording = isRecording
            if isRecording {
                // Auto-show the window when recording starts
                AudioLevelWindowManager.shared.showWindow()
            } else {
                // Auto-hide the window when recording stops
                AudioLevelWindowManager.shared.hideWindow()
            }
        }
    }
}

// MARK: - Audio Level Window Manager using NSPanel
@MainActor
class AudioLevelWindowManager: ObservableObject {
    static let shared = AudioLevelWindowManager()
    
    private var audioLevelPanel: NSPanel?
    
    private init() {
        setupPanel()
    }
    
    private func setupPanel() {
        let panelRect = NSRect(x: 0, y: 0, width: 60, height: 80)
        
        audioLevelPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        
        guard let panel = audioLevelPanel else { return }
        
        // Configure panel properties inspired by the provided code
        panel.level = .mainMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.identifier = NSUserInterfaceItemIdentifier("audio-levels")
        
        // Set up the SwiftUI hosting view
        let hostingView = NSHostingView(rootView: AudioLevelWindowView())
        hostingView.frame = panelRect
        panel.contentView = hostingView
        
        // Position the panel in the top-right corner of the screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = NSRect(
                x: screenFrame.maxX - panelRect.width - 20,
                y: screenFrame.maxY - panelRect.height - 20,
                width: panelRect.width,
                height: panelRect.height
            )
            panel.setFrame(panelFrame, display: false)
        }
    }
    
    func showWindow() {
        guard let panel = audioLevelPanel else {
            setupPanel()
            showWindow()
            return
        }
        
        panel.orderFrontRegardless()
    }
    
    func hideWindow() {
        audioLevelPanel?.orderOut(nil)
    }
} 