import SwiftUI

struct BrowseView: View {
    @Environment(ItemStore.self) private var store
    @State private var category: ItemCategory?
    @State private var maxDistance: Double = 10

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Category", selection: $category) {
                        Text("All").tag(ItemCategory?.none)
                        ForEach(ItemCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage)
                                .tag(ItemCategory?.some(category))
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Within \(maxDistance, specifier: "%.0f") km")
                        Slider(value: $maxDistance, in: 1...25, step: 1)
                    }
                }

                Section("Nearby") {
                    let results = store.items(in: category, within: maxDistance)
                    if results.isEmpty {
                        ContentUnavailableView("Nothing nearby yet", systemImage: "tray", description: Text("Try a wider distance or another category."))
                    }
                    ForEach(results) { item in
                        NavigationLink(value: item) {
                            ItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Circlo")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
        }
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            Image(systemName: item.category.systemImage)
                .frame(width: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text(item.title)
                Text("\(item.distanceKm, specifier: "%.1f") km away")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.isFree ? "Free" : "Swap")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15), in: Capsule())
        }
    }
}

struct ItemDetailView: View {
    @Environment(ItemStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    var body: some View {
        Form {
            Section {
                Text(item.details)
            }
            Section("Details") {
                LabeledContent("Category", value: item.category.title)
                LabeledContent("Distance", value: String(format: "%.1f km", item.distanceKm))
                LabeledContent("Offer", value: item.isFree ? "Free" : "Exchange")
            }
            Section {
                Button("Arrange pickup") {
                    // Placeholder for messaging / scheduling.
                }
                Button("Report completed exchange") {
                    store.markExchanged(item)
                    dismiss()
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    BrowseView()
        .environment(ItemStore())
}
