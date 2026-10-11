import Foundation
import SwiftUI

struct Track: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var artist: String
    var urlString: String
    var duration: TimeInterval
    
    var fileURL: URL {
        URL(fileURLWithPath: urlString)
    }
    
    init(id: UUID = UUID(), title: String, artist: String, urlString: String, duration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.artist = artist
        self.urlString = urlString
        self.duration = duration
    }
}

struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var colorHex: String // e.g. "#FF5733"
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    init(id: UUID = UUID(), name: String, tracks: [Track] = [], colorHex: String = "#3B82F6") {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.colorHex = colorHex
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    var hexString: String {
        // Simple conversion for common colors or NSColor
        #if os(macOS)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.blue
        let red = Int(nsColor.redComponent * 255)
        let green = Int(nsColor.greenComponent * 255)
        let blue = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
        #else
        return "#3B82F6"
        #endif
    }
}
