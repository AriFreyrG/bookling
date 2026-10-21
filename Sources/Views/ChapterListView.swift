import SwiftUI

struct ChapterListView: View {
    let book: Audiobook
    @EnvironmentObject var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(book.chapters) { chapter in
                    Button {
                        var target = book
                        target.currentChapterIndex = chapter.index
                        target.currentTimeInChapter = 0
                        library.audioManager.load(book: target)
                        library.audioManager.play()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.title)
                                    .font(.subheadline.weight(library.audioManager.currentChapterIndex == chapter.index ? .semibold : .regular))
                                    .foregroundStyle(library.audioManager.currentChapterIndex == chapter.index ? Color.accentColor : .primary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if library.audioManager.currentChapterIndex == chapter.index {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text(book.formattedDuration(chapter.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

