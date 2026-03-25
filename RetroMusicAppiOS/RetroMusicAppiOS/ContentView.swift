import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var showDocumentPicker = false
    @State private var selectedFileURL: URL?
    @State private var folders: [Folder] = []

    @StateObject var connectivityManager = WatchConnectivityManager()
    @StateObject var audioPlayerManager = AudioPlayerManager()

    private static var foldersFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_folders.json")
    }

    // All tracks across all folders (for quick play)
    private var allMusicTracks: [AudioTrack] {
        folders.flatMap { $0.audioTracks.filter { !$0.isPodcast } }
    }

    private var allPodcastTracks: [AudioTrack] {
        folders.flatMap { $0.audioTracks.filter { $0.isPodcast } }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // iPod screen area
                VStack(spacing: 0) {
                    IPodTitleBar(title: "RetroMusic")

                    VStack(spacing: 0) {
                        NavigationLink(destination: FolderListView(
                            folders: $folders,
                            showDocumentPicker: $showDocumentPicker,
                            selectedFileURL: $selectedFileURL,
                            connectivityManager: connectivityManager,
                            audioPlayerManager: audioPlayerManager
                        )) {
                            IPodMenuRow(label: "Music", icon: "music.note")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()

                        NavigationLink(destination: PlaylistsView(
                            folders: $folders,
                            audioPlayerManager: audioPlayerManager
                        )) {
                            IPodMenuRow(label: "Playlists", icon: "music.note.list")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()

                        NavigationLink(destination: PodcastsView(
                            tracks: allPodcastTracks,
                            audioPlayerManager: audioPlayerManager
                        )) {
                            IPodMenuRow(label: "Podcasts", icon: "mic.fill")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()

                        NavigationLink(destination: ArtistsView(
                            tracks: allMusicTracks,
                            audioPlayerManager: audioPlayerManager
                        )) {
                            IPodMenuRow(label: "Artists", icon: "person.2.fill")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()

                        NavigationLink(destination: SettingsView(connectivityManager: connectivityManager)) {
                            IPodMenuRow(label: "Settings", icon: "gearshape.fill")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()

                        NavigationLink(destination: AboutView()) {
                            IPodMenuRow(label: "About", icon: "info.circle.fill")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()
                    }

                    // Now playing mini bar
                    if audioPlayerManager.isPlaying || !audioPlayerManager.currentTrackTitle.isEmpty {
                        nowPlayingBar
                    }
                }
                .background(IPodTheme.backgroundGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 16)

                // Click wheel
                IPodClickWheel(
                    onMenu: nil,
                    onPrevious: { audioPlayerManager.playPreviousTrack() },
                    onNext: { audioPlayerManager.playNextTrack() },
                    onPlayPause: { audioPlayerManager.playPause() },
                    onSelect: nil
                )
                .padding(.bottom, 20)
            }
            .background(Color(white: 0.92).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: loadFolders)
        .onChange(of: folders) { _ in saveFolders() }
    }

    private var nowPlayingBar: some View {
        NavigationLink(destination: iOSNowPlayingView(
            audioPlayerManager: audioPlayerManager,
            tracks: audioPlayerManager.playlist,
            initialTrackIndex: max(0, audioPlayerManager.currentTrackIndex)
        )) {
            HStack(spacing: 8) {
                if let artwork = audioPlayerManager.currentTrackArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "music.note")
                        .frame(width: 30, height: 30)
                        .foregroundColor(IPodTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(audioPlayerManager.currentTrackTitle)
                        .font(IPodTheme.font(12, weight: .semibold))
                        .foregroundColor(IPodTheme.textPrimary)
                        .lineLimit(1)
                    Text(audioPlayerManager.currentTrackArtist)
                        .font(IPodTheme.font(10))
                        .foregroundColor(IPodTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(IPodTheme.highlightStart)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(IPodTheme.titleBarGradient)
        }
    }

    // MARK: - Persistence

    private func saveFolders() {
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: Self.foldersFileURL, options: .atomic)
        } catch {
            print("Error saving folders: \(error.localizedDescription)")
        }
    }

    private func loadFolders() {
        if FileManager.default.fileExists(atPath: Self.foldersFileURL.path) {
            do {
                let data = try Data(contentsOf: Self.foldersFileURL)
                let decoded = try JSONDecoder().decode([Folder].self, from: data)
                if !decoded.isEmpty {
                    folders = decoded
                    return
                }
            } catch {
                print("Error loading folders from JSON: \(error.localizedDescription)")
            }
        }

        // Migrate from UserDefaults
        if let savedData = UserDefaults.standard.data(forKey: "folders"),
           let decoded = try? JSONDecoder().decode([Folder].self, from: savedData),
           !decoded.isEmpty {
            folders = decoded
            UserDefaults.standard.removeObject(forKey: "folders")
            saveFolders()
            return
        }

        folders = [Folder(id: UUID(), name: "My Music", audioTracks: [])]
    }
}

// MARK: - Playlists View (shows all folders as playlists)

struct PlaylistsView: View {
    @Binding var folders: [Folder]
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Playlists")

            List {
                // "All Songs" playlist
                let allTracks = folders.flatMap { $0.audioTracks }
                if !allTracks.isEmpty {
                    NavigationLink(destination: SimpleTrackListView(
                        title: "All Songs",
                        tracks: allTracks,
                        audioPlayerManager: audioPlayerManager
                    )) {
                        IPodMenuRow(label: "All Songs (\(allTracks.count))", icon: "music.note.list")
                    }
                    .buttonStyle(IPodButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                ForEach(folders) { folder in
                    if !folder.audioTracks.isEmpty {
                        NavigationLink(destination: SimpleTrackListView(
                            title: folder.name,
                            tracks: folder.audioTracks,
                            audioPlayerManager: audioPlayerManager
                        )) {
                            IPodMenuRow(label: "\(folder.name) (\(folder.audioTracks.count))", icon: "music.note.list")
                        }
                        .buttonStyle(IPodButtonStyle())
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Podcasts View

struct PodcastsView: View {
    let tracks: [AudioTrack]
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Podcasts")

            if tracks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "mic.slash")
                        .font(.system(size: 40))
                        .foregroundColor(IPodTheme.textSecondary)
                    Text("No podcasts yet")
                        .font(IPodTheme.font(16))
                        .foregroundColor(IPodTheme.textSecondary)
                    Text("Import audio files that will be detected as podcasts")
                        .font(IPodTheme.font(12))
                        .foregroundColor(IPodTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                SimpleTrackListContent(
                    tracks: tracks,
                    audioPlayerManager: audioPlayerManager
                )
            }
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Artists View

struct ArtistsView: View {
    let tracks: [AudioTrack]
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    private var artistGroups: [(String, [AudioTrack])] {
        let grouped = Dictionary(grouping: tracks) { $0.artist ?? "Unknown Artist" }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Artists")

            if artistGroups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundColor(IPodTheme.textSecondary)
                    Text("No artists yet")
                        .font(IPodTheme.font(16))
                        .foregroundColor(IPodTheme.textSecondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(artistGroups, id: \.0) { artist, artistTracks in
                        NavigationLink(destination: SimpleTrackListView(
                            title: artist,
                            tracks: artistTracks,
                            audioPlayerManager: audioPlayerManager
                        )) {
                            IPodMenuRow(label: "\(artist) (\(artistTracks.count))", icon: "person.fill")
                        }
                        .buttonStyle(IPodButtonStyle())
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var connectivityManager: WatchConnectivityManager

    private var storageUsed: String {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return "N/A"
        }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "N/A"
        }
        var total: UInt64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        if total < 1024 * 1024 {
            return String(format: "%.0f KB", Double(total) / 1024)
        }
        return String(format: "%.1f MB", Double(total) / (1024 * 1024))
    }

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Settings")

            VStack(spacing: 0) {
                settingsRow(label: "Storage Used", value: storageUsed)
                IPodSeparator()
                settingsRow(label: "Max Transfer Size", value: "50 MB")
                IPodSeparator()
                settingsRow(label: "Watch Connected", value: WCSessionAvailable ? "Yes" : "No")
                IPodSeparator()
            }

            Spacer()
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var WCSessionAvailable: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(IPodTheme.font(15))
                .foregroundColor(IPodTheme.textPrimary)
            Spacer()
            Text(value)
                .font(IPodTheme.font(14))
                .foregroundColor(IPodTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "About")

            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(IPodTheme.highlightStart)

                Text("RetroMusic")
                    .font(IPodTheme.font(24, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)

                Text("iPod-style music player\nfor iPhone & Apple Watch")
                    .font(IPodTheme.font(14))
                    .foregroundColor(IPodTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Text("v1.0")
                    .font(IPodTheme.font(12))
                    .foregroundColor(IPodTheme.textSecondary)

                Spacer()
            }
            .padding()
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable Track List

struct SimpleTrackListView: View {
    let title: String
    let tracks: [AudioTrack]
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: title)
            SimpleTrackListContent(tracks: tracks, audioPlayerManager: audioPlayerManager)
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SimpleTrackListContent: View {
    let tracks: [AudioTrack]
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @State private var navigateToNowPlaying = false
    @State private var selectedIndex = 0

    var body: some View {
        List {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                Button {
                    selectedIndex = index
                    audioPlayerManager.setPlaylist(tracks, startAt: index)
                    audioPlayerManager.playTrack(at: index)
                    navigateToNowPlaying = true
                } label: {
                    IPodTrackRow(track: track)
                }
                .buttonStyle(IPodButtonStyle())
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            NavigationLink(
                destination: iOSNowPlayingView(
                    audioPlayerManager: audioPlayerManager,
                    tracks: tracks,
                    initialTrackIndex: selectedIndex
                ),
                isActive: $navigateToNowPlaying
            ) { EmptyView() }
        )
    }
}

