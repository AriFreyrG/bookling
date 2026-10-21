import Foundation
import Combine
import UIKit

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var books: [Audiobook] = []
    @Published var searchQuery = ""
    @Published var sortOrder: SortOrder = .lastPlayed
    @Published var currentBook: Audiobook?

    let audioManager = AudioManager.shared
    private let libraryService = LibraryService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Save periodically while playing, so progress survives the app being
        // terminated in the background.
        audioManager.$currentTime
            .throttle(for: .seconds(15), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                guard let self, self.audioManager.isPlaying else { return }
                self.saveProgress()
            }
            .store(in: &cancellables)
    }

    enum SortOrder: String, CaseIterable {
        case lastPlayed = "Recent"
        case title = "Title"
        case author = "Author"
        case dateAdded = "Newest"
    }

    var filteredBooks: [Audiobook] {
        var result = books
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.author.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        switch sortOrder {
        case .lastPlayed: result.sort { $0.lastPlayedDate > $1.lastPlayedDate }
        case .title: result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .author: result.sort { $0.author.localizedCompare($1.author) == .orderedAscending }
        case .dateAdded: result.sort { $0.dateAdded > $1.dateAdded }
        }
        return result
    }

    func refreshLibrary() {
        books = libraryService.scanLibrary()
    }

    func selectBook(_ book: Audiobook) {
        // Keep the position reached in the book being switched away from.
        if currentBook != nil, currentBook?.id != book.id {
            saveProgress()
        }
        var updated = book
        if let savedBook = books.first(where: { $0.id == book.id }) {
            updated = savedBook
        }
        currentBook = updated
        audioManager.load(book: updated)
    }

    func saveProgress() {
        guard var book = currentBook else { return }
        let state = audioManager.getCurrentState(for: book.id)
        book.currentChapterIndex = state.chapterIndex
        book.currentTimeInChapter = state.timeInChapter
        book.playbackSpeed = state.speed
        book.lastPlayedDate = .now
        libraryService.saveProgress(for: book)
        if let idx = books.firstIndex(where: { $0.id == book.id }) {
            books[idx] = book
        }
        currentBook = book
    }

    func resetProgress(for bookId: UUID) {
        libraryService.resetProgress(for: bookId)
        refreshLibrary()
    }

    func loadCoverImage(for book: Audiobook) -> UIImage? {
        libraryService.loadCoverImage(for: book)
    }

    func playRandomBook() {
        guard !books.isEmpty else { return }
        let randomIndex = Int.random(in: 0..<books.count)
        var book = books[randomIndex]

        guard !book.chapters.isEmpty else { return }
        let randomChapter = Int.random(in: 0..<book.chapters.count)
        let chapterDuration = max(book.chapters[randomChapter].duration, 1)
        let randomTime = Double.random(in: 0..<chapterDuration)

        book.currentChapterIndex = randomChapter
        book.currentTimeInChapter = randomTime
        book.lastPlayedDate = .now

        currentBook = book
        audioManager.cancelSleepTimer()
        audioManager.load(book: book)
        audioManager.play()
    }
}
