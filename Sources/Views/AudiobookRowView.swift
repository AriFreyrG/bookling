import SwiftUI

struct AudiobookRowView: View {
    let book: Audiobook
    @EnvironmentObject var library: LibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            coverImage
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .overlay(alignment: .bottomTrailing) {
                    if book.progress > 0 {
                        progressBadge
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                if book.author != "Unknown Author" {
                    Text(book.author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(book.formattedDuration(book.totalDuration))
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var coverImage: some View {
        Group {
            if let image = library.loadCoverImage(for: book) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var progressBadge: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 28, height: 28)

            Circle()
                .trim(from: 0, to: book.progress)
                .stroke(Color.accentColor, lineWidth: 2.5)
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))
        }
        .padding(4)
    }
}
