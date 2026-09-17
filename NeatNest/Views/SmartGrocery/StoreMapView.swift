import SwiftUI
import MapKit

struct StoreMapView: View {
    let retailers: [Retailer]
    let prices: [RetailerProductPrice]
    let activeItems: [UserGroceryListItem]

    @State private var selectedRetailer: Retailer?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private var retailersWithLocation: [Retailer] {
        retailers.filter { $0.hasLocation }
    }

    private func itemsAvailable(at retailer: Retailer) -> Int {
        let retailerProductIds = Set(
            prices
                .filter { $0.retailerId == retailer.id && $0.isAvailable }
                .map(\.productCatalogId)
        )
        return activeItems.filter { item in
            guard let catalogId = item.productCatalogId else { return false }
            return retailerProductIds.contains(catalogId)
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if retailersWithLocation.isEmpty {
                noLocationView
            } else {
                mapView
                if let selected = selectedRetailer {
                    storeDetailPanel(for: selected)
                }
            }
        }
        .navigationTitle("Supermercati")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var noLocationView: some View {
        VStack(spacing: 16) {
            SmartGroceryEmptyState(
                icon: "map",
                title: "Nessuna posizione disponibile",
                subtitle: "I supermercati nel database non hanno coordinate GPS."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Supermercati disponibili")
                    .font(.headline)
                    .padding(.horizontal, 20)

                ForEach(retailers) { retailer in
                    retailerRow(retailer)
                }
            }
        }
    }

    @ViewBuilder
    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: retailersWithLocation) { retailer in
            MapAnnotation(coordinate: CLLocationCoordinate2D(
                latitude: retailer.latitude ?? 0,
                longitude: retailer.longitude ?? 0
            )) {
                mapPin(for: retailer)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func mapPin(for retailer: Retailer) -> some View {
        let available = itemsAvailable(at: retailer)
        let isSelected = selectedRetailer?.id == retailer.id

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.green : Color.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .green)
            }

            if available > 0 {
                Text("\(available)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: Capsule())
            }
        }
        .onTapGesture {
            withAnimation {
                selectedRetailer = retailer
            }
        }
    }

    private func storeDetailPanel(for retailer: Retailer) -> some View {
        let available = itemsAvailable(at: retailer)
        let storeProductIds = Set(
            prices
                .filter { $0.retailerId == retailer.id && $0.isAvailable }
                .map(\.productCatalogId)
        )
        let matchingItems = activeItems.filter { item in
            guard let catalogId = item.productCatalogId else { return false }
            return storeProductIds.contains(catalogId)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(retailer.name)
                        .font(.headline)
                    if let area = retailer.cityArea {
                        Text(area)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let address = retailer.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(available)/\(activeItems.count)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("prodotti disponibili")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !matchingItems.isEmpty {
                Divider()
                ForEach(matchingItems.prefix(5)) { item in
                    HStack {
                        Text(item.displayName)
                            .font(.subheadline)
                        Spacer()
                        if let price = prices.first(where: { $0.retailerId == retailer.id && $0.productCatalogId == item.productCatalogId }) {
                            Text(price.effectivePrice(considerLoyaltyPricing: true), format: .euro)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            Button {
                selectedRetailer = nil
            } label: {
                Text("Chiudi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -10)
        )
    }

    private func retailerRow(_ retailer: Retailer) -> some View {
        let available = itemsAvailable(at: retailer)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(retailer.name)
                    .font(.subheadline.weight(.medium))
                if let area = retailer.cityArea {
                    Text(area)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(available) prodotti")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}