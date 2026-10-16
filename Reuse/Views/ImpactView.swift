import SwiftUI

struct ImpactView: View {
    @Environment(ItemStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        ImpactStat(value: "\(store.exchangedItems.count)", label: "Items passed on")
                        Divider()
                        ImpactStat(value: String(format: "%.1f kg", store.kilogramsDiverted), label: "Waste diverted")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                Section("Completed exchanges") {
                    if store.exchangedItems.isEmpty {
                        Text("Nothing yet. Report an exchange from an item's page.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.exchangedItems) { item in
                        Label(item.title, systemImage: item.category.systemImage)
                    }
                }
            }
            .navigationTitle("Your Impact")
        }
    }
}

private struct ImpactStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack {
            Text(value).font(.largeTitle.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ImpactView()
        .environment(ItemStore())
}
