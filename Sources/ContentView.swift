import SwiftUI

struct ContentView: View {
    @EnvironmentObject var library: LibraryViewModel
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            LibraryView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if library.currentBook != nil {
                            Button {
                                showPlayer = true
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showPlayer) {
                    if let book = library.currentBook {
                        PlayerView(book: book)
                            .environmentObject(library)
                    }
                }
        }
        .onShake {
            library.playRandomBook()
            showPlayer = true
        }
    }
}
