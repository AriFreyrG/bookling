import Foundation
import AVFoundation
import UIKit

final class LibraryService {
    static let shared = LibraryService()

    private let fileManager = FileManager.default

    private var audiobooksDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Audiobooks", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var metadataURL: URL {
        audiobooksDirectory.appendingPathComponent(".library_metadata.json")
    }

    private var metadata: [UUID: SavedProgress] = [:]

    private struct SavedProgress: Codable {
        var currentChapterIndex: Int
        var currentTimeInChapter: TimeInterval
        var playbackSpeed: Double
        var lastPlayedDate: Date
    }

    private init() {
        loadMetadata()
    }

    func scanLibrary() -> [Audiobook] {
        var books: [Audiobook] = []
        guard let contents = try? fileManager.contentsOfDirectory(
            at: audiobooksDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        for url in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                if let book = scanFolderBook(at: url) {
                    books.append(book)
                }
            } else {
                if let book = scanSingleFileBook(at: url) {
                    books.append(book)
                }
            }
        }

        let sorted = books.sorted { $0.lastPlayedDate > $1.lastPlayedDate }
        for var book in sorted {
            if let saved = metadata[book.id] {
                book.currentChapterIndex = saved.currentChapterIndex
                book.currentTimeInChapter = saved.currentTimeInChapter
                book.playbackSpeed = saved.playbackSpeed
                book.lastPlayedDate = saved.lastPlayedDate
            }
        }
        return sorted
    }

    private func scanFolderBook(at url: URL) -> Audiobook? {
        let supportedExtensions = ["mp3", "m4a", "m4b", "aac", "wav", "aiff", "wma"]
        guard let files = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let audioFiles = files
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !audioFiles.isEmpty else { return nil }

        var chapters: [Chapter] = []
        for (index, file) in audioFiles.enumerated() {
            let asset = AVAsset(url: file)
            let duration = asset.duration.seconds.isNaN ? 0 : asset.duration.seconds
            let title = file.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "^[0-9]+[_\\-\\.\\s]*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespaces)
            chapters.append(Chapter(
                title: title,
                filename: file.lastPathComponent,
                duration: duration,
                index: index
            ))
        }

        let cover = findCover(in: url)
        let title = url.lastPathComponent

        var author = "Unknown Author"
        if let authorFile = files.first(where: { $0.lastPathComponent.lowercased() == "author.txt" }),
           let authorText = try? String(contentsOf: authorFile, encoding: .utf8) {
            author = authorText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let id: UUID
        if let existing = metadata.first(where: { $0.key.uuidString == title }) {
            id = existing.key
        } else {
            id = UUID()
        }

        return Audiobook(
            id: id,
            title: title,
            author: author,
            chapters: chapters,
            folderPath: url.lastPathComponent,
            artworkPath: cover?.lastPathComponent,
            dateAdded: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
        )
    }

    private func scanSingleFileBook(at url: URL) -> Audiobook? {
        let supportedExtensions = ["mp3", "m4a", "m4b", "aac", "wav", "aiff"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }

        let asset = AVAsset(url: url)
        let duration = asset.duration.seconds.isNaN ? 0 : asset.duration.seconds
        let title = url.deletingPathExtension().lastPathComponent

        let chapterMetadata = loadChapters(from: asset) ?? [
            Chapter(title: title, filename: url.lastPathComponent, duration: duration, index: 0)
        ]

        let id: UUID
        if let existing = metadata.first(where: { $0.key.uuidString == title }) {
            id = existing.key
        } else {
            id = UUID()
        }

        return Audiobook(
            id: id,
            title: title,
            chapters: chapterMetadata,
            folderPath: url.lastPathComponent,
            dateAdded: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
        )
    }

    private func loadChapters(from asset: AVAsset) -> [Chapter]? {
        let chapters = asset.chapters
        guard !chapters.isEmpty else { return nil }
        return chapters.enumerated().map { (i, chapter) in
            let title = chapter.title ?? "Chapter \(i + 1)"
            let duration = chapter.timeRange.duration.seconds
            return Chapter(title: title, filename: "", duration: duration, index: i)
        }
    }

    private func findCover(in directory: URL) -> URL? {
        let coverNames = ["cover.jpg", "cover.jpeg", "cover.png", "Cover.jpg", "Cover.jpeg", "Cover.png", "folder.jpg"]
        for name in coverNames {
            let url = directory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    func loadCoverImage(for book: Audiobook) -> UIImage? {
        let bookDir = audiobooksDirectory.appendingPathComponent(book.folderPath)
        if let artworkPath = book.artworkPath {
            let url = bookDir.appendingPathComponent(artworkPath)
            if let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        }
        return nil
    }

    func audioFileURL(for book: Audiobook, chapter: Chapter) -> URL? {
        if !chapter.filename.isEmpty {
            let url = audiobooksDirectory.appendingPathComponent(book.folderPath).appendingPathComponent(chapter.filename)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        let url = audiobooksDirectory.appendingPathComponent(book.folderPath)
        if fileManager.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    func saveProgress(for book: Audiobook) {
        metadata[book.id] = SavedProgress(
            currentChapterIndex: book.currentChapterIndex,
            currentTimeInChapter: book.currentTimeInChapter,
            playbackSpeed: book.playbackSpeed,
            lastPlayedDate: book.lastPlayedDate
        )
        saveMetadata()
    }

    func resetProgress(for bookId: UUID) {
        metadata.removeValue(forKey: bookId)
        saveMetadata()
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([UUID: SavedProgress].self, from: data)
        else { return }
        metadata = decoded
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}
