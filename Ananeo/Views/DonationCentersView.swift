import SwiftUI

struct DonationCentersView: View {
    @Environment(PlacesStore.self) private var store

    var body: some View {
        NavigationStack {
            List(store.donationCenters) { center in
                VStack(alignment: .leading, spacing: 4) {
                    Text(center.name).font(.headline)
                    Text(center.address).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(center.distanceMiles, specifier: "%.1f") mi · accepts \(center.accepts.map(\.title).joined(separator: ", "))")
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
        .environment(PlacesStore())
}
