import MapKit
import SwiftUI

struct MapView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var profileStore: OnboardingStore
    @EnvironmentObject private var savedItems: SavedItemsStore
    @StateObject private var locationService = LocationService()
    @State private var selectedPlaceID: String?
    @State private var focusRequestID = UUID()

    private var mappablePlaces: [Place] {
        dataStore.places.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var selectedPlace: Place? {
        guard let selectedPlaceID else { return nil }
        return dataStore.places.first { $0.id == selectedPlaceID }
    }

    private var focusCoordinate: CLLocationCoordinate2D? {
        if let latitude = locationService.latitude, let longitude = locationService.longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        if let latitude = profileStore.profile.latitude, let longitude = profileStore.profile.longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if mappablePlaces.isEmpty {
                    PathlyDashboardBackground()
                    ContentUnavailableView(
                        "No Mappable Places",
                        systemImage: "map",
                        description: Text("Places without map pins are still available in Explore.")
                    )
                } else {
                    map
                    mapSummary
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let selectedPlace {
                    selectedPlaceCard(selectedPlace)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedPlaceID)
            .onChange(of: locationService.latitude) { _, latitude in
                if latitude != nil { focusRequestID = UUID() }
            }
        }
    }

    private var map: some View {
        ClusteredPlacesMap(
            places: mappablePlaces,
            focusCoordinate: focusCoordinate,
            focusState: profileStore.profile.inferredStateCode,
            focusRequestID: focusRequestID,
            selectedPlaceID: $selectedPlaceID
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var mapSummary: some View {
        HStack(spacing: 11) {
            Image(systemName: "mappin.and.ellipse")
                .font(.headline)
                .foregroundStyle(PathlyDashboardTheme.accent)
                .frame(width: 38, height: 38)
                .background(PathlyDashboardTheme.accent.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(mappablePlaces.count.formatted()) places on the map")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PathlyDashboardTheme.primaryText)
                Text("Tap a pin to view details")
                    .font(.caption)
                    .foregroundStyle(PathlyDashboardTheme.secondaryText)
            }

            Spacer(minLength: 4)

            Button(action: recenterMap) {
                Image(systemName: locationService.isWorking ? "location.fill.viewfinder" : "location.fill")
                    .font(.headline)
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(PathlyDashboardTheme.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(locationService.isWorking)
            .accessibilityLabel("Center map near me")
        }
        .padding(12)
        .pathlyDashboardCard(cornerRadius: 18)
    }

    private func recenterMap() {
        if focusCoordinate != nil || profileStore.profile.inferredStateCode != nil {
            focusRequestID = UUID()
        } else {
            locationService.requestCurrentLocation()
        }
        PathlyHaptics.selection()
    }

    private func selectedPlaceCard(_ place: Place) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: place.placeType.mapSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PathlyDashboardTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(PathlyDashboardTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 5) {
                    Text(place.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(PathlyDashboardTheme.primaryText)
                        .lineLimit(2)
                    Text([place.city, place.state].compactMap { $0 }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                    Text(place.placeType.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PathlyDashboardTheme.softAccent)
                }

                Spacer(minLength: 4)

                Button {
                    selectedPlaceID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PathlyDashboardTheme.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(PathlyDashboardTheme.elevatedSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close place details")
            }

            Divider().overlay(PathlyDashboardTheme.border)

            Button {
                savedItems.toggle(place.id)
                PathlyHaptics.selection()
            } label: {
                Label(
                    savedItems.contains(place.id) ? "Saved" : "Save",
                    systemImage: savedItems.contains(place.id) ? "bookmark.fill" : "bookmark"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PathlyDashboardTheme.softAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(PathlyDashboardTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)

            NavigationLink {
                PlaceDetailView(
                    place: place,
                    organization: place.organizationID.flatMap { organizationID in
                        dataStore.organizations.first { $0.id == organizationID }
                    }
                )
            } label: {
                Label("View details", systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(PathlyDashboardTheme.accent, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .pathlyDashboardCard(cornerRadius: 20)
    }
}

private extension PlaceType {
    var mapSymbol: String {
        switch self {
        case .library: "books.vertical.fill"
        case .makerspace, .fabLab, .hackerspace, .innovationLab: "wrench.and.screwdriver.fill"
        case .museum, .scienceCenter: "building.columns.fill"
        case .university: "graduationcap.fill"
        case .roboticsClub: "gearshape.2.fill"
        case .communityCenter, .youthCenter: "person.3.fill"
        case .observatory: "moon.stars.fill"
        }
    }
}
