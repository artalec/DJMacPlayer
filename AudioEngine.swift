import Foundation
import AVFoundation
import SwiftUI
import Combine

class AudioEngine: ObservableObject {
    private var engine = AVAudioEngine()
    private var playerNodeA = AVAudioPlayerNode()
    private var playerNodeB = AVAudioPlayerNode()
    private var eqNodeA = AVAudioUnitEQ(numberOfBands: 1)
    private var eqNodeB = AVAudioUnitEQ(numberOfBands: 1)
    
    private var activePlayer: AVAudioPlayerNode!
    private var activeEQ: AVAudioUnitEQ!
    private var inactivePlayer: AVAudioPlayerNode!
    private var inactiveEQ: AVAudioUnitEQ!
    
    private var audioFileA: AVAudioFile?
    private var audioFileB: AVAudioFile?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var waveformSamples: [Float] = []
    
    // Settings
    @Published var crossfadeEnabled = true
    @Published var crossfadeDuration: Double = 3.0 // seconds
    @Published var lowCutEnabled = false
    
    private var timer: Timer?
    private var currentTrackURL: URL?
    
    init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(playerNodeA)
        engine.attach(playerNodeB)
        
        // Setup Low-cut filter via EQ (High-Pass filter at 500Hz when active)
        configureEQ(eqNodeA)
        configureEQ(eqNodeB)
        
        engine.attach(eqNodeA)
        engine.attach(eqNodeB)
        
        let format = engine.outputNode.outputFormat(forBus: 0)
        
        engine.connect(playerNodeA, to: eqNodeA, format: format)
        engine.connect(eqNodeA, to: engine.mainMixerNode, format: format)
        
        engine.connect(playerNodeB, to: eqNodeB, format: format)
        engine.connect(eqNodeB, to: engine.mainMixerNode, format: format)
        
        activePlayer = playerNodeA
        activeEQ = eqNodeA
        inactivePlayer = playerNodeB
        inactiveEQ = eqNodeB
        
        do {
            try engine.start()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }
    
    private func configureEQ(_ eq: AVAudioUnitEQ) {
        let band = eq.bands[0]
        band.filterType = .highPass
        band.frequency = 20.0 // Normal (flat/no low cut)
        band.bandwidth = 0.5
        band.gain = 0
        band.bypass = false
    }
    
    func loadTrack(_ url: URL) {
        currentTrackURL = url
        do {
            let file = try AVAudioFile(forReading: url)
            duration = Double(file.length) / file.processingFormat.sampleRate
            audioFileA = file
            generateWaveform(for: url)
        } catch {
            print("Error loading audio file: \(error)")
        }
    }
    
    func play(trackURL: URL) {
        loadTrack(trackURL)
        
        do {
            let file = try AVAudioFile(forReading: trackURL)
            
            if isPlaying && crossfadeEnabled {
                // Crossfade to inactive player
                let nextPlayer = inactivePlayer
                let nextEQ = inactiveEQ
                let currPlayer = activePlayer
                let currEQ = activeEQ
                
                nextPlayer?.stop()
                nextPlayer?.scheduleFile(file, at: nil) {
                    // completion
                }
                nextPlayer?.volume = 0.0
                nextPlayer?.play()
                
                // Fade in new, fade out old
                let fadeSteps = 30
                let interval = crossfadeDuration / Double(fadeSteps)
                let volStep = 1.0 / Double(fadeSteps)
                
                // Low-cut effect on current player if enabled
                if lowCutEnabled {
                    let band = currEQ.bands[0]
                    band.frequency = 800.0 // Sweep up frequency for low-cut DJ effect
                }
                
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
                    guard let self = self else { t.invalidate(); return }
                    if let p1 = currPlayer, let p2 = nextPlayer {
                        if p1.volume > Float(volStep) {
                            p1.volume -= Float(volStep)
                            p2.volume += Float(volStep)
                        } else {
                            p1.stop()
                            p2.volume = 1.0
                            t.invalidate()
                            // Reset EQ bypass/freq
                            self.configureEQ(currEQ)
                        }
                    } else {
                        t.invalidate()
                    }
                }
                
                // Swap active
                activePlayer = nextPlayer
                activeEQ = nextEQ
                inactivePlayer = currPlayer
                inactiveEQ = currEQ
                
            } else {
                // Normal play / stop previous
                activePlayer.stop()
                activePlayer.volume = 1.0
                configureEQ(activeEQ)
                
                activePlayer.scheduleFile(file, at: nil, completionHandler: nil)
                activePlayer.play()
            }
            
            isPlaying = true
            startTimer()
            
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    func stop() {
        activePlayer.stop()
        inactivePlayer.stop()
        isPlaying = false
        stopTimer()
        currentTime = 0
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying {
                // Simple time increment approximation or node timestamp
                if let nodeTime = self.activePlayer.lastRenderTime,
                   let playerTime = self.activePlayer.playerTime(forNodeTime: nodeTime) {
                    let time = Double(playerTime.sampleTime) / playerTime.sampleRate
                    if time >= 0 && time <= self.duration {
                        self.currentTime = time
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func generateWaveform(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let frameCount = UInt32(file.length)
                
                guard frameCount > 0 else { return }
                
                // Read into buffer
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
                try file.read(into: buffer!)
                
                guard let channelData = buffer?.floatChannelData?[0] else { return }
                let samplesCount = Int(buffer!.frameLength)
                
                // Downsample to 100 bars for waveform UI
                let targetCount = 100
                var waveform: [Float] = []
                let strideSize = max(1, samplesCount / targetCount)
                
                for i in 0..<targetCount {
                    let index = i * strideSize
                    if index < samplesCount {
                        let sample = abs(channelData[index])
                        waveform.append(min(1.0, sample * 2.0))
                    }
                }
                
                DispatchQueue.main.async {
                    self.waveformSamples = waveform
                }
            } catch {
                print("Waveform generation error: \(error)")
                DispatchQueue.main.async {
                    self.waveformSamples = Array(repeating: 0.1, count: 100)
                }
            }
        }
    }
}
