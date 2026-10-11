import SwiftUI
import UniformTypeIdentifiers

class AppViewModel: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var selectedPlaylistID: UUID?
    @Published var currentTrack: Track?
    
    private let saveFileURL: URL = {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = docs.appendingPathComponent("DJMacPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("playlists.json")
    }()
    
    init() {
        loadData()
        if playlists.isEmpty {
            // Default playlist
            let defaultPlaylist = Playlist(name: "My First Playlist", tracks: [], colorHex: "#3B82F6")
            playlists.append(defaultPlaylist)
            selectedPlaylistID = defaultPlaylist.id
        } else if selectedPlaylistID == nil {
            selectedPlaylistID = playlists.first?.id
        }
    }
    
    func saveData() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: saveFileURL)
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }
    
    func loadData() {
        do {
            let data = try Data(contentsOf: saveFileURL)
            playlists = try JSONDecoder().decode([Playlist].self, from: data)
        } catch {
            print("No saved data found or failed to decode.")
        }
    }
    
    func addPlaylist(name: String, colorHex: String = "#10B981") {
        let newPl = Playlist(name: name, tracks: [], colorHex: colorHex)
        playlists.append(newPl)
        selectedPlaylistID = newPl.id
        saveData()
    }
    
    func removePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        if selectedPlaylistID == playlist.id {
            selectedPlaylistID = playlists.first?.id
        }
        saveData()
    }
    
    func addTracks(to playlistID: UUID, urls: [URL]) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        for url in urls {
            let title = url.deletingPathExtension().lastPathComponent
            let track = Track(title: title, artist: "Unknown Artist", urlString: url.path)
            playlists[index].tracks.append(track)
        }
        saveData()
    }
    
    func removeTrack(from playlistID: UUID, at offsets: IndexSet) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].tracks.remove(atOffsets: offsets)
        saveData()
    }
    
    func exportPlaylist(_ playlist: Playlist, to url: URL) {
        do {
            let data = try JSONEncoder().encode(playlist)
            try data.write(to: url)
        } catch {
            print("Export error: \(error)")
        }
    }
    
    func importPlaylist(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let playlist = try JSONDecoder().decode(Playlist.self, from: data)
            playlists.append(playlist)
            selectedPlaylistID = playlist.id
            saveData()
        } catch {
            print("Import error: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var audioEngine = AudioEngine()
    
    @State private var newPlaylistName = ""
    @State private var showingNewPlaylistAlert = false
    @State private var selectedTrackID: UUID?
    @State private var editingPlaylist: Playlist?
    
    var body: some View {
        NavigationSplitView {
            // Left Pane: Playlists
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Playlists")
                        .font(.headline)
                        .padding(.leading)
                    Spacer()
                    Button(action: { showingNewPlaylistAlert = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing)
                }
                .padding(.vertical, 10)
                
                Divider()
                
                List(selection: $viewModel.selectedPlaylistID) {
                    ForEach($viewModel.playlists) { $playlist in
                        HStack {
                            Circle()
                                .fill(playlist.color)
                                .frame(width: 12, height: 12)
                            
                            Text(playlist.name)
                                .tag(playlist.id)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Rename") {
                                editingPlaylist = playlist
                            }
                            Button("Delete", role: .destructive) {
                                viewModel.removePlaylist(playlist)
                            }
                            Button("Export Playlist...") {
                                exportPlaylistDialog(playlist)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        viewModel.playlists.move(fromOffsets: indices, toOffset: newOffset)
                        viewModel.saveData()
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // Import button
                HStack {
                    Button("Import Playlist...") {
                        importPlaylistDialog()
                    }
                    .font(.caption)
                    .padding(8)
                    Spacer()
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            
        } detail: {
            // Right Pane: Track List & Waveform & Top DJ Controls
            VStack(spacing: 0) {
                // Top section: Waveform & Controls
                VStack(spacing: 8) {
                    // Top Bar: Crossfade & LowCut controls
                    HStack {
                        Text(viewModel.currentTrack?.title ?? "No Track Playing")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Crossfade control
                        HStack(spacing: 6) {
                            Toggle("Crossfade", isOn: $audioEngine.crossfadeEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            
                            if audioEngine.crossfadeEnabled {
                                Slider(value: $audioEngine.crossfadeDuration, in: 1.0...10.0, step: 0.5)
                                    .frame(width: 80)
                                Text(String(format: "%.1fs", audioEngine.crossfadeDuration))
                                    .font(.caption2)
                                    .frame(width: 30)
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        Divider().frame(height: 20)
                        
                        // Low-cut filter control (DJ effect)
                        Toggle(isOn: $audioEngine.lowCutEnabled) {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.path.badge.minus")
                                Text("Low-Cut Filter")
                            }
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .tint(audioEngine.lowCutEnabled ? .orange : .accentColor)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Waveform View (always has a dedicated place)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 60)
                        
                        if audioEngine.waveformSamples.isEmpty {
                            Text("Waveform Display")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 2) {
                                ForEach(Array(audioEngine.waveformSamples.enumerated()), id: \.offset) { index, sample in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Double(index) / 100.0 <= (audioEngine.currentTime / max(1, audioEngine.duration)) ? Color.green : Color.blue.opacity(0.6))
                                        .frame(width: 3, height: max(4, CGFloat(sample) * 50))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Track List
                if let selectedID = viewModel.selectedPlaylistID,
                   let playlistIndex = viewModel.playlists.firstIndex(where: { $0.id == selectedID }) {
                    
                    let playlist = viewModel.playlists[playlistIndex]
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(playlist.name)
                                .font(.title2)
                                .bold()
                            Spacer()
                            Button("Add Audio Files...") {
                                selectAudioFiles(for: playlist.id)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        
                        List(selection: $selectedTrackID) {
                            ForEach(playlist.tracks) { track in
                                HStack {
                                    Image(systemName: viewModel.currentTrack?.id == track.id && audioEngine.isPlaying ? "speaker.wave.2.fill" : "music.note")
                                        .foregroundColor(viewModel.currentTrack?.id == track.id ? .green : .primary)
                                    Text(track.title)
                                        .bold(viewModel.currentTrack?.id == track.id)
                                    Spacer()
                                    Text(track.artist)
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    playTrack(track)
                                }
                            }
                            .onDelete { indexSet in
                                viewModel.removeTrack(from: playlist.id, at: indexSet)
                            }
                        }
                        .dropDestination(for: URL.self) { items, location in
                            viewModel.addTracks(to: playlist.id, urls: items)
                            return true
                        }
                    }
                } else {
                    Text("Select a playlist")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        // Keyboard Shortcuts: Space to play selected track, Esc to stop
        .background(
            HStack {
                Button("") {
                    // Space key action
                    if let trackID = selectedTrackID,
                       let playlistID = viewModel.selectedPlaylistID,
                       let playlist = viewModel.playlists.first(where: { $0.id == playlistID }),
                       let track = playlist.tracks.first(where: { $0.id == trackID }) {
                        playTrack(track)
                    }
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("") {
                    // Esc key action
                    audioEngine.stop()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .hidden()
        )
        .alert("New Playlist", isPresented: $showingNewPlaylistAlert) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Create") {
                if !newPlaylistName.isEmpty {
                    viewModel.addPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        }
        .sheet(item: $editingPlaylist) { playlist in
            PlaylistEditView(playlist: playlist) { updatedName, updatedHex in
                if let idx = viewModel.playlists.firstIndex(where: { $0.id == playlist.id }) {
                    viewModel.playlists[idx].name = updatedName
                    viewModel.playlists[idx].colorHex = updatedHex
                    viewModel.saveData()
                }
            }
        }
    }
    
    private func playTrack(_ track: Track) {
        viewModel.currentTrack = track
        audioEngine.play(trackURL: track.fileURL)
    }
    
    private func selectAudioFiles(for playlistID: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            viewModel.addTracks(to: playlistID, urls: panel.urls)
        }
    }
    
    private func exportPlaylist(_ playlist: Playlist) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(playlist.name).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.exportPlaylist(playlist, to: url)
        }
    }
    
    private func exportPlaylistDialog(_ playlist: Playlist) {
        exportPlaylist(playlist)
    }
    
    private func importPlaylistDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importPlaylist(from: url)
        }
    }
}

struct PlaylistEditView: View {
    let playlist: Playlist
    var onSave: (String, String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var colorHex: String
    
    init(playlist: Playlist, onSave: @escaping (String, String) -> Void) {
        self.playlist = playlist
        self.onSave = onSave
        _name = State(initialValue: playlist.name)
        _colorHex = State(initialValue: playlist.colorHex)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Playlist")
                .font(.headline)
            
            TextField("Playlist Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            ColorPicker("Highlight Color", selection: Binding(
                get: { Color(hex: colorHex) ?? .blue },
                set: { colorHex = $0.hexString }
            ))
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(name, colorHex)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 180)
    }
}
