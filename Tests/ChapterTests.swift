import XCTest
@testable import AudiobookApp

final class ChapterTests: XCTestCase {

    func testChapterInitialization() {
        let chapter = Chapter(title: "Intro", filename: "01.mp3", duration: 120.5, index: 0)
        
        XCTAssertEqual(chapter.title, "Intro")
        XCTAssertEqual(chapter.filename, "01.mp3")
        XCTAssertEqual(chapter.duration, 120.5)
        XCTAssertEqual(chapter.index, 0)
        XCTAssertNotNil(chapter.id)
    }

    func testChapterEquatable() {
        let id = UUID()
        let ch1 = Chapter(id: id, title: "Ch1", filename: "1.mp3", duration: 100, index: 0)
        let ch2 = Chapter(id: id, title: "Ch1", filename: "1.mp3", duration: 100, index: 0)
        let ch3 = Chapter(title: "Ch1", filename: "1.mp3", duration: 100, index: 0)
        
        XCTAssertEqual(ch1, ch2)
        XCTAssertNotEqual(ch1, ch3) // Different UUIDs
    }

    func testChapterIdentifiable() {
        let chapter = Chapter(title: "Test", filename: "test.mp3", duration: 50, index: 1)
        XCTAssertNotNil(chapter.id)
    }
}
