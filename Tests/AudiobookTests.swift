import XCTest
@testable import AudiobookApp

final class AudiobookTests: XCTestCase {

    func testTotalDuration() {
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 60, index: 0),
            Chapter(title: "Ch2", filename: "2.mp3", duration: 120, index: 1)
        ]
        let book = Audiobook(title: "Test", chapters: chapters, folderPath: "/test")
        XCTAssertEqual(book.totalDuration, 180)
    }

    func testCurrentGlobalTime() {
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0),
            Chapter(title: "Ch2", filename: "2.mp3", duration: 200, index: 1),
            Chapter(title: "Ch3", filename: "3.mp3", duration: 300, index: 2)
        ]
        var book = Audiobook(title: "Test", chapters: chapters, folderPath: "/test")
        
        // Start of book
        XCTAssertEqual(book.currentGlobalTime, 0)
        
        // Middle of second chapter
        book.currentChapterIndex = 1
        book.currentTimeInChapter = 50
        XCTAssertEqual(book.currentGlobalTime, 150) // 100 (Ch1) + 50
        
        // End of book
        book.currentChapterIndex = 2
        book.currentTimeInChapter = 300
        XCTAssertEqual(book.currentGlobalTime, 600) // 100 + 200 + 300
    }

    func testProgress() {
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0),
            Chapter(title: "Ch2", filename: "2.mp3", duration: 100, index: 1)
        ]
        var book = Audiobook(title: "Test", chapters: chapters, folderPath: "/test")
        
        XCTAssertEqual(book.progress, 0)
        
        book.currentChapterIndex = 1
        book.currentTimeInChapter = 50
        XCTAssertEqual(book.progress, 0.75) // (100 + 50) / 200
        
        book.currentChapterIndex = 1
        book.currentTimeInChapter = 100
        XCTAssertEqual(book.progress, 1.0)
    }

    func testProgressZeroDuration() {
        let book = Audiobook(title: "Test", chapters: [], folderPath: "/test")
        XCTAssertEqual(book.progress, 0)
    }

    func testIsFinished() {
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0),
            Chapter(title: "Ch2", filename: "2.mp3", duration: 100, index: 1)
        ]
        var book = Audiobook(title: "Test", chapters: chapters, folderPath: "/test")
        
        XCTAssertFalse(book.isFinished)
        
        // Almost finished
        book.currentChapterIndex = 1
        book.currentTimeInChapter = 98
        XCTAssertFalse(book.isFinished)
        
        // Finished (within 1 second of end)
        book.currentTimeInChapter = 99.5
        XCTAssertTrue(book.isFinished)
        
        // Past end
        book.currentTimeInChapter = 105
        XCTAssertTrue(book.isFinished)
    }

    func testIsFinishedEmptyChapters() {
        let book = Audiobook(title: "Test", chapters: [], folderPath: "/test")
        XCTAssertFalse(book.isFinished)
    }

    func testFormattedDuration() {
        let book = Audiobook(title: "Test", chapters: [], folderPath: "/test")
        XCTAssertEqual(book.formattedDuration(65), "1:05")
        XCTAssertEqual(book.formattedDuration(3665), "1:01:05")
        XCTAssertEqual(book.formattedDuration(0), "0:00")
    }

    func testFormattedRemaining() {
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0)
        ]
        var book = Audiobook(title: "Test", chapters: chapters, folderPath: "/test")
        
        XCTAssertEqual(book.formattedRemaining(from: 20), "-1:20")
        XCTAssertEqual(book.formattedRemaining(from: 100), "-0:00")
        XCTAssertEqual(book.formattedRemaining(from: 150), "-0:00") // Clamped to 0
    }

    func testProgressLabel() {
        let chapters = [
            Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0)
        ]
        var book = Audiobook(title: "Test", chapters: chapters, folderPath: "/test")
        book.currentChapterIndex = 0
        book.currentTimeInChapter = 30
        
        XCTAssertEqual(book.progressLabel, "0:30 / 1:40")
    }
}
