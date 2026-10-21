# Bookling

An audiobook player for iPhone and iPad, built with SwiftUI. Drop audiobooks into the
app's Documents folder and Bookling keeps your place in each one. Shake the phone to
jump to a random spot in a random book.

## Features

- Library grid with search and sorting (recent, title, author, newest)
- Per-book progress, chapter and playback speed, saved automatically
- Chapter list, 10 s back / 30 s forward, speeds from 0.5x to 3x
- Sleep timer (15/30/45/60 minutes or end of chapter)
- Background playback
- Shake to play a random book

## Requirements

- Xcode 15 or later
- iOS 17.0 or later

## Adding audiobooks

Books live in `Documents/Audiobooks/` inside the app. Copy files there with the Files app
(On My iPhone > Audiobook App) or Finder file sharing.

- **Folder book:** a folder containing audio files. Each file is one chapter, ordered by
  filename; a leading track number such as `01 - ` is stripped from the chapter title.
  Optional `cover.jpg`/`cover.png` (or `folder.jpg`) is used as artwork and an optional
  `author.txt` sets the author.
- **Single-file book:** one audio file directly in `Audiobooks/`. It plays as a single
  chapter; embedded chapter markers (e.g. in `.m4b`) are not read yet.

Supported formats: mp3, m4a, m4b, aac, wav, aiff.

Saved progress is keyed by the book's file or folder name, so renaming a book resets its
progress.

## Development

Open `AudiobookApp.xcodeproj` and run the `AudiobookApp` scheme. To run the tests from the
command line:

```sh
xcodebuild test -project AudiobookApp.xcodeproj -scheme AudiobookApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI runs the same tests and an unsigned Release build on every pull request
(`.github/workflows/ci.yml`).

## Releasing

1. Set your Apple Developer team and a bundle identifier you own on the `AudiobookApp`
   target (Signing & Capabilities).
2. Add a 1024x1024 app icon to `Resources/Assets.xcassets/AppIcon.appiconset`.
3. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the target's build settings and
   update `CHANGELOG.md`.
4. Product > Archive, then distribute through App Store Connect.
