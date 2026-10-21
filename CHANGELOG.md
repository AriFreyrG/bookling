# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [1.0.0] - Unreleased

First release.

### Added

- Library of folder and single-file audiobooks with search and sorting.
- Player with chapter navigation, skip back/forward, playback speed and sleep timer.
- Shake to play a random book at a random position.
- Background audio playback.
- Unit test target, shared Xcode scheme and GitHub Actions CI.
- Privacy manifest (`PrivacyInfo.xcprivacy`) declaring file timestamp access.

### Fixed

- Listening progress is now restored after relaunch. Books previously got a new ID on
  every library scan, so saved progress was never found.
- Progress is saved every 15 seconds while playing and when the app leaves the
  foreground, not only on play/pause.
- Switching books no longer records the previous book's position for the new one.
- The "End of Chapter" sleep timer now pauses at the end of the chapter (it did nothing).
- Opening the app no longer interrupts audio from other apps; the audio session is
  activated on play.
- Build errors: removed use of a nonexistent `AVAsset.chapters` API and an undefined
  `.accent` style, and set the project's iOS SDK.
- WMA files are no longer listed as chapters, since iOS cannot play them.
