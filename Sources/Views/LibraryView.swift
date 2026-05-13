import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryViewModel
    @State private var showPlayer = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if library.filteredBooks.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(library.filteredBooks) { book in
                        AudiobookRowView(book: book)
                            .onTapGesture {
                                library.selectBook(book)
                                showPlayer = true
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Library")
        .searchable(text: $library.searchQuery, prompt: "Search audiobooks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let book = library.currentBook {
                PlayerView(book: book)
                    .environmentObject(library)
            }
        }
        .onAppear {
            library.refreshLibrary()
        }
        .refreshable {
            library.refreshLibrary()
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(LibraryViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    library.sortOrder = order
                } label: {
                    HStack {
                        Text(order.rawValue)
                        if library.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Audiobooks Found")
                .font(.title2.weight(.semibold))

            Text("Add audiobook files to your app's Documents/Audiobooks folder via iTunes File Sharing or the Files app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 100)
    }
}
