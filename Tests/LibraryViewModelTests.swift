import XCTest
@testable import AudiobookApp

@MainActor
final class LibraryViewModelTests: XCTestCase {

    func testFilteredBooksEmptySearch() {
        let viewModel = LibraryViewModel()
        viewModel.books = [
            Audiobook(title: "Book A", chapters: [], folderPath: "/a"),
            Audiobook(title: "Book B", chapters: [], folderPath: "/b")
        ]
        viewModel.searchQuery = ""
        
        XCTAssertEqual(viewModel.filteredBooks.count, 2)
    }

    func testFilteredBooksSearchQuery() {
        let viewModel = LibraryViewModel()
        viewModel.books = [
            Audiobook(title: "Harry Potter", author: "JK Rowling", chapters: [], folderPath: "/hp"),
            Audiobook(title: "Lord of the Rings", author: "Tolkien", chapters: [], folderPath: "/lotr")
        ]
        viewModel.searchQuery = "harry"
        
        XCTAssertEqual(viewModel.filteredBooks.count, 1)
        XCTAssertEqual(viewModel.filteredBooks.first?.title, "Harry Potter")
    }

    func testFilteredBooksSearchAuthor() {
        let viewModel = LibraryViewModel()
        viewModel.books = [
            Audiobook(title: "Book 1", author: "Author A", chapters: [], folderPath: "/1"),
            Audiobook(title: "Book 2", author: "Author B", chapters: [], folderPath: "/2")
        ]
        viewModel.searchQuery = "author b"
        
        XCTAssertEqual(viewModel.filteredBooks.count, 1)
        XCTAssertEqual(viewModel.filteredBooks.first?.author, "Author B")
    }

    func testFilteredBooksSortByTitle() {
        let viewModel = LibraryViewModel()
        viewModel.books = [
            Audiobook(title: "Zebra", chapters: [], folderPath: "/z"),
            Audiobook(title: "Apple", chapters: [], folderPath: "/a")
        ]
        viewModel.sortOrder = .title
        
        XCTAssertEqual(viewModel.filteredBooks.first?.title, "Apple")
        XCTAssertEqual(viewModel.filteredBooks.last?.title, "Zebra")
    }

    func testPlayRandomBookEmptyLibrary() {
        let viewModel = LibraryViewModel()
        viewModel.books = []
        
        viewModel.playRandomBook()
        XCTAssertNil(viewModel.currentBook)
    }

    func testPlayRandomBookSelectsValidBookAndChapter() {
        let viewModel = LibraryViewModel()
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0),
            Chapter(title: "Ch2", filename: "2.mp3", duration: 100, index: 1)
        ]
        viewModel.books = [
            Audiobook(title: "Book A", chapters: chapters, folderPath: "/a"),
            Audiobook(title: "Book B", chapters: chapters, folderPath: "/b")
        ]
        
        // Run multiple times to increase chance of hitting different random paths
        for _ in 0..<10 {
            viewModel.playRandomBook()
            
            XCTAssertNotNil(viewModel.currentBook)
            let selectedBook = viewModel.currentBook!
            
            XCTAssertTrue(selectedBook.currentChapterIndex >= 0)
            XCTAssertTrue(selectedBook.currentChapterIndex < selectedBook.chapters.count)
            XCTAssertTrue(selectedBook.currentTimeInChapter >= 0)
            
            let chapterDuration = selectedBook.chapters[selectedBook.currentChapterIndex].duration
            XCTAssertTrue(selectedBook.currentTimeInChapter < max(chapterDuration, 1))
        }
    }

    func testPlayRandomBookWithEmptyChapters() {
        let viewModel = LibraryViewModel()
        viewModel.books = [
            Audiobook(title: "Empty Book", chapters: [], folderPath: "/empty")
        ]
        
        viewModel.playRandomBook()
        // Should return early due to guard !book.chapters.isEmpty
        // Depending on implementation, currentBook might remain nil or unchanged.
        // In current code: guard !book.chapters.isEmpty else { return }
        // So currentBook should be nil if it was nil before.
        XCTAssertNil(viewModel.currentBook)
    }
}
