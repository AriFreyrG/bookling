import Foundation

struct Audiobook: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var chapters: [Chapter]
    var folderPath: String
    var artworkPath: String?
    var currentChapterIndex: Int
    var currentTimeInChapter: TimeInterval
    var playbackSpeed: Double
    var lastPlayedDate: Date
    var dateAdded: Date

    var totalDuration: TimeInterval {
        chapters.reduce(0) { $0 + $1.duration }
    }

    var currentGlobalTime: TimeInterval {
        let completedDuration = chapters[..<currentChapterIndex].reduce(0) { $0 + $1.duration }
        return completedDuration + currentTimeInChapter
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return currentGlobalTime / totalDuration
    }

    var isFinished: Bool {
        guard let last = chapters.last else { return false }
        return currentChapterIndex >= chapters.count - 1 && currentTimeInChapter >= last.duration - 1
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "Unknown Author",
        chapters: [Chapter],
        folderPath: String,
        artworkPath: String? = nil,
        currentChapterIndex: Int = 0,
        currentTimeInChapter: TimeInterval = 0,
        playbackSpeed: Double = 1.0,
        lastPlayedDate: Date = .distantPast,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.chapters = chapters
        self.folderPath = folderPath
        self.artworkPath = artworkPath
        self.currentChapterIndex = currentChapterIndex
        self.currentTimeInChapter = currentTimeInChapter
        self.playbackSpeed = playbackSpeed
        self.lastPlayedDate = lastPlayedDate
        self.dateAdded = dateAdded
    }
}

extension Audiobook {
    static let timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    func formattedDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formattedRemaining(from current: TimeInterval) -> String {
        let remaining = max(0, totalDuration - current)
        return "-" + formattedDuration(remaining)
    }

    var progressLabel: String {
        "\(formattedDuration(currentGlobalTime)) / \(formattedDuration(totalDuration))"
    }
}
