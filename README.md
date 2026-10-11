# DJMacPlayer

A professional macOS music player built with SwiftUI and AVFoundation, featuring custom playlists, persistent storage, real-time audio waveforms, crossfade, and a DJ-style low-cut filter effect.

## Features

1. **Playlist Management**: Create, rename, reorder playlists, and customize their highlight color. Export and import playlists easily.
2. **Playback Controls**: Press **Space** to start a selected track, press **Esc** to stop. Tracks automatically stop when the next track begins.
3. **Automatic Persistence**: All added audio files and playlists automatically save and persist across app sessions.
4. **Waveform Display**: A dedicated waveform view at the top of the app window for the currently playing track.
5. **Crossfade**: Top-right crossfade toggle with adjustable transition duration.
6. **DJ Low-Cut Filter**: Switchable low-cut filter effect for smooth track transitions.

---

## How to Upload to GitHub and Compile

### Step 1: Initialize Git Repository Locally
Open your Terminal, navigate to the project folder containing `Package.swift`, and initialize git:

```bash
cd /path/to/DJMacPlayer
git init
git add .
git commit -m "Initial commit: DJMacPlayer macOS app"
```

### Step 2: Create a Repository on GitHub
1. Go to [GitHub](https://github.com) and click **New repository**.
2. Name your repository (e.g., `DJMacPlayer`).
3. Leave it public or private, do **not** initialize with a README (since you already have one).
4. Click **Create repository**.

### Step 3: Push to GitHub
Copy the remote repository URL from GitHub and run:

```bash
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/DJMacPlayer.git
git push -u origin main
```

### Step 4: Compile and Run on macOS
You can compile and run this project using **Xcode** or **Swift Package Manager**:

#### Option A: Using Xcode
1. Open Xcode.
2. Choose **File > New > Project from Git...** (or clone your GitHub repository locally).
3. Alternatively, open Terminal in your cloned repo directory and generate an Xcode project:
   ```bash
   swift package generate-xcodeproj
   ```
   *(Or simply open the folder directly in Xcode since Xcode natively supports Swift Packages).*
4. Select the **DJMacPlayer** scheme and target **My Mac**.
5. Press **Cmd + R** to build and run the application!

#### Option B: Using Command Line (Swift Package Manager)
```bash
swift build -c release
```
The compiled binary will be located at `.build/release/DJMacPlayer`.
