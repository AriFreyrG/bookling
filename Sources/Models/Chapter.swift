import Foundation

struct Chapter: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var filename: String
    var duration: TimeInterval
    var index: Int

    init(id: UUID = UUID(), title: String, filename: String, duration: TimeInterval, index: Int) {
        self.id = id
        self.title = title
        self.filename = filename
        self.duration = duration
        self.index = index
    }
}
