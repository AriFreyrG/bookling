import SwiftUI

struct SleepTimerPicker: View {
    @EnvironmentObject var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    let options: [(label: String, duration: TimeInterval)] = [
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("45 minutes", 45 * 60),
        ("1 hour", 60 * 60),
        ("End of Chapter", -1),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.label) { option in
                        Button {
                            if option.duration == -1 {
                                library.audioManager.startSleepTimerEndOfChapter()
                            } else {
                                library.audioManager.startSleepTimer(after: option.duration)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Text(option.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Stop playing after...")
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
