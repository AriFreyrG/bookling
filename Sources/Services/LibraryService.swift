import Foundation
import AVFoundation
import CryptoKit
import UIKit

final class LibraryService {
    static let shared = LibraryService()

    // AVFoundation cannot decode WMA, so it is deliberately not listed.
    private static let supportedExtensions: Set<String> = ["mp3", "m4a", "m4b", "aac", "wav", "aiff"]

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
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
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

        for i in books.indices {
            guard let saved = metadata[books[i].id] else { continue }
            books[i].currentChapterIndex = min(saved.currentChapterIndex, max(books[i].chapters.count - 1, 0))
            books[i].currentTimeInChapter = saved.currentTimeInChapter
            books[i].playbackSpeed = saved.playbackSpeed
            books[i].lastPlayedDate = saved.lastPlayedDate
        }
        return books.sorted { $0.lastPlayedDate > $1.lastPlayedDate }
    }

    /// Derives a stable ID from the book's path inside the Audiobooks folder,
    /// so saved progress survives rescans and app relaunches.
    private func stableID(for relativePath: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(relativePath.utf8)).prefix(16))
        return bytes.withUnsafeBufferPointer { NSUUID(uuidBytes: $0.baseAddress!) as UUID }
    }

    private func scanFolderBook(at url: URL) -> Audiobook? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let audioFiles = files
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
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

        return Audiobook(
            id: stableID(for: url.lastPathComponent),
            title: title,
            author: author,
            chapters: chapters,
            folderPath: url.lastPathComponent,
            artworkPath: cover?.lastPathComponent,
            dateAdded: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
        )
    }

    private func scanSingleFileBook(at url: URL) -> Audiobook? {
        guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }

        let asset = AVAsset(url: url)
        let duration = asset.duration.seconds.isNaN ? 0 : asset.duration.seconds
        let title = url.deletingPathExtension().lastPathComponent

        // Embedded chapters (e.g. in .m4b files) are not supported yet: the player
        // can only play whole files, so a single-file book is one chapter.
        let chapters = [
            Chapter(title: title, filename: "", duration: duration, index: 0)
        ]

        return Audiobook(
            id: stableID(for: url.lastPathComponent),
            title: title,
            chapters: chapters,
            folderPath: url.lastPathComponent,
            dateAdded: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
        )
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
        // Single-file books store the file itself in folderPath.
        let url = audiobooksDirectory.appendingPathComponent(book.folderPath)
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
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
