import SwiftUI

struct DonationCentersView: View {
    @Environment(ItemStore.self) private var store

    var body: some View {
        NavigationStack {
            List(store.donationCenters) { center in
                VStack(alignment: .leading, spacing: 4) {
                    Text(center.name).font(.headline)
                    Text(center.address).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(center.distanceKm, specifier: "%.1f") km · accepts \(center.accepts.map(\.title).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Donation Centers")
        }
    }
}

#Preview {
    DonationCentersView()
        .environment(ItemStore())
}
