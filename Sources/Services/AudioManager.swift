import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentChapterIndex: Int = 0
    @Published var chapters: [Chapter] = []
    @Published var playbackSpeed: Float = 1.0

    @Published var sleepTimerRemaining: TimeInterval?
    @Published var sleepAtEndOfChapter = false
    private var sleepTimerWork: DispatchWorkItem?
    private var sleepTimerStart: Date?
    private var sleepTimerDuration: TimeInterval?
    private var pendingPlay = false

    var currentChapter: Chapter? {
        guard currentChapterIndex < chapters.count else { return nil }
        return chapters[currentChapterIndex]
    }

    var isSleepTimerActive: Bool {
        sleepTimerRemaining != nil || sleepAtEndOfChapter
    }

    var chapterProgress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?

    private let libraryService = LibraryService.shared
    private var currentFolderPath: String = ""

    private override init() {
        super.init()
        setupAudioSession()
    }

    // The session is only activated on play, so launching the app does not
    // interrupt audio from other apps.
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    func load(book: Audiobook) {
        chapters = book.chapters
        currentChapterIndex = book.currentChapterIndex
        currentFolderPath = book.folderPath
        playbackSpeed = Float(book.playbackSpeed)
        loadChapter(at: currentChapterIndex, seekTo: book.currentTimeInChapter)
    }

    private func loadChapter(at index: Int, seekTo time: TimeInterval = 0) {
        guard index < chapters.count else { return }
        let chapter = chapters[index]
        currentChapterIndex = index
        // Reflect the target position right away, so progress saved before the
        // new item is ready does not pick up the previous chapter's time.
        currentTime = time
        duration = chapter.duration

        let tempBook = Audiobook(title: "", chapters: chapters, folderPath: currentFolderPath)
        guard let url = libraryService.audioFileURL(for: tempBook, chapter: chapter) else {
            let asset = AVAsset(url: URL(fileURLWithPath: ""))
            loadPlayerItem(AVPlayerItem(asset: asset))
            return
        }

        removeObservers()
        let item = AVPlayerItem(url: url)
        loadPlayerItem(item, seekTo: time)
    }

    private func loadPlayerItem(_ item: AVPlayerItem, seekTo time: TimeInterval = 0) {
        removeObservers()

        if player == nil {
            player = AVPlayer()
        }
        player?.replaceCurrentItem(with: item)
        playerItem = item

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .readyToPlay {
                self.duration = item.duration.seconds
                if time > 0 {
                    self.seek(to: time)
                }
                if self.pendingPlay {
                    self.pendingPlay = false
                    self.player?.play()
                    self.player?.rate = self.playbackSpeed
                }
            }
        }

        rateObserver = player?.observe(\.rate, options: [.new]) { [weak self] player, _ in
            self?.isPlaying = player.rate > 0
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, let item = self.playerItem, item.status == .readyToPlay else { return }
            self.currentTime = time.seconds
            self.checkSleepTimer()
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.advanceToNextChapter()
        }
    }

    private func removeObservers() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
    }

    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
        pendingPlay = true
        guard let item = playerItem, item.status == .readyToPlay else { return }
        pendingPlay = false
        player?.play()
        player?.rate = playbackSpeed
    }

    func pause() {
        pendingPlay = false
        player?.pause()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    func skipBackward(_ seconds: TimeInterval = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    func nextChapter() {
        guard currentChapterIndex + 1 < chapters.count else { return }
        loadChapter(at: currentChapterIndex + 1)
        if isPlaying { play() }
    }

    func previousChapter() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard currentChapterIndex > 0 else {
            seek(to: 0)
            return
        }
        loadChapter(at: currentChapterIndex - 1)
        if isPlaying { play() }
    }

    private func advanceToNextChapter() {
        if currentChapterIndex + 1 < chapters.count {
            loadChapter(at: currentChapterIndex + 1)
            if sleepAtEndOfChapter {
                sleepAtEndOfChapter = false
                pause()
            } else {
                play()
            }
        } else {
            sleepAtEndOfChapter = false
            isPlaying = false
            pause()
        }
    }

    func getCurrentState(for bookId: UUID) -> (chapterIndex: Int, timeInChapter: TimeInterval, speed: Double) {
        (currentChapterIndex, currentTime, Double(playbackSpeed))
    }

    // MARK: - Sleep Timer

    func startSleepTimer(after duration: TimeInterval) {
        cancelSleepTimer()
        sleepTimerDuration = duration
        sleepTimerStart = Date()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.pause()
                self?.sleepTimerRemaining = nil
                self?.sleepTimerDuration = nil
                self?.sleepTimerStart = nil
            }
        }
        sleepTimerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        sleepTimerRemaining = duration
    }

    func startSleepTimerEndOfChapter() {
        cancelSleepTimer()
        sleepAtEndOfChapter = true
    }

    func cancelSleepTimer() {
        sleepTimerWork?.cancel()
        sleepTimerWork = nil
        sleepAtEndOfChapter = false
        sleepTimerRemaining = nil
        sleepTimerDuration = nil
        sleepTimerStart = nil
    }

    private func checkSleepTimer() {
        guard let start = sleepTimerStart, let duration = sleepTimerDuration else { return }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = max(0, duration - elapsed)
        if remaining <= 0 {
            pause()
            cancelSleepTimer()
        } else {
            sleepTimerRemaining = remaining
        }
    }
}
