import SwiftUI

struct PlayerView: View {
    let book: Audiobook
    @EnvironmentObject var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showChapters = false
    @State private var showSleepPicker = false
    @State private var dragOffset: CGFloat = 0

    private let impact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView
            contentView
            dragHandle
        }
        .interactiveDismissDisabled()
        .onReceive(library.audioManager.$isPlaying) { _ in
            library.saveProgress()
        }
        .sheet(isPresented: $showChapters) {
            ChapterListView(book: book)
                .environmentObject(library)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSleepPicker) {
            SleepTimerPicker()
                .environmentObject(library)
                .presentationDetents([.height(340)])
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.quaternary)
            .frame(width: 36, height: 5)
            .padding(.top, 10)
    }

    private var backgroundView: some View {
        Group {
            if let image = library.loadCoverImage(for: book) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .overlay(.regularMaterial)
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            Spacer()

            artworkSection
                .padding(.horizontal, 40)

            Spacer()

            titleSection
                .padding(.horizontal, 24)

            progressSection
                .padding(.horizontal, 24)
                .padding(.top, 24)

            controlsSection
                .padding(.top, 20)

            bottomTools
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
        }
    }

    private var artworkSection: some View {
        Group {
            if let image = library.loadCoverImage(for: book) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)
                        .frame(width: 200, height: 200)
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(library.audioManager.currentChapter?.title ?? book.title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            if book.author != "Unknown Author" {
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { library.audioManager.currentTime },
                    set: { library.audioManager.seek(to: $0) }
                ),
                in: 0...max(library.audioManager.duration, 1)
            )
            .accentColor(.primary)

            HStack {
                Text(book.formattedDuration(library.audioManager.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(book.formattedRemaining(from: library.audioManager.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 40) {
            Button { skipBack() } label: {
                Image(systemName: "gobackward.10")
                    .font(.title)
            }
            .foregroundStyle(.primary)

            Button { library.audioManager.previousChapter() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .foregroundStyle(.primary)

            Button {
                impact.impactOccurred()
                library.audioManager.togglePlayPause()
            } label: {
                Image(systemName: library.audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .foregroundStyle(.primary)

            Button { library.audioManager.nextChapter() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .foregroundStyle(.primary)

            Button { skipForward() } label: {
                Image(systemName: "goforward.30")
                    .font(.title)
            }
            .foregroundStyle(.primary)
        }
    }

    private var bottomTools: some View {
        HStack(spacing: 0) {
            speedButton
            Spacer()
            chapterListButton
            Spacer()
            sleepTimerButton
            Spacer()
            dismissButton
        }
    }

    private var speedButton: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0], id: \.self) { speed in
                Button {
                    library.audioManager.setPlaybackSpeed(Float(speed))
                } label: {
                    HStack {
                        Text("\(speed, specifier: "%.2f")x")
                            .monospacedDigit()
                        if abs(Double(library.audioManager.playbackSpeed) - speed) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(library.audioManager.playbackSpeed, specifier: "%.2f")x")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("Speed")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var chapterListButton: some View {
        Button {
            showChapters = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "list.bullet")
                    .font(.title3)
                Text("Chapters")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
        }
    }

    private var sleepTimerButton: some View {
        Button {
            if library.audioManager.isSleepTimerActive {
                library.audioManager.cancelSleepTimer()
            } else {
                showSleepPicker = true
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: library.audioManager.isSleepTimerActive ? "moon.fill" : "moon")
                    .font(.title3)
                Text("Sleep")
                    .font(.caption2)
            }
            .foregroundStyle(library.audioManager.isSleepTimerActive ? Color.accentColor : .primary)
        }
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                Text("Close")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
        }
    }

    private func skipForward() {
        library.audioManager.skipForward(30)
    }

    private func skipBack() {
        library.audioManager.skipBackward(10)
    }
}
