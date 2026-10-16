import SwiftUI

struct ListItemView: View {
    @Environment(ItemStore.self) private var store
    @State private var title = ""
    @State private var details = ""
    @State private var category: ItemCategory = .household
    @State private var isFree = true
    @State private var didPost = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you giving away?") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                    Toggle("Offer for free", isOn: $isFree)
                }
                Section {
                    Button("Post item") {
                        store.add(Item(title: title, details: details, category: category, distanceKm: 0, isFree: isFree))
                        title = ""
                        details = ""
                        didPost = true
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Give")
            .alert("Posted", isPresented: $didPost) {
                Button("OK") {}
            } message: {
                Text("Your item is now visible to people nearby.")
            }
        }
    }
}

#Preview {
    ListItemView()
        .environment(ItemStore())
}
