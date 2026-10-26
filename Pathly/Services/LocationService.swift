import Combine
import CoreLocation
import Foundation
import MapKit

struct ResolvedDiscoveryLocation: Equatable {
    let postalCode: String
    let name: String
    let stateCode: String
    let latitude: Double
    let longitude: Double
}

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isWorking = false
    @Published private(set) var postalCode = ""
    @Published private(set) var resolvedLocation = ""
    @Published private(set) var stateCode = ""
    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    @Published private(set) var errorMessage: String?
    @Published private(set) var selection: ResolvedDiscoveryLocation?

    private let manager = CLLocationManager()
    private var geocodingRequest: MKGeocodingRequest?
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
    private var requestedCurrentLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestCurrentLocation() {
        cancelLookup()
        errorMessage = nil
        requestedCurrentLocation = true

        switch manager.authorizationStatus {
        case .notDetermined:
            isWorking = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isWorking = true
            manager.requestLocation()
        case .denied, .restricted:
            requestedCurrentLocation = false
            errorMessage = "Location access is unavailable. Enter your ZIP code instead."
        @unknown default:
            requestedCurrentLocation = false
            errorMessage = "Enter your ZIP code to choose a location."
        }
    }

    /// Refreshes a previously authorized location without triggering a permission prompt.
    func refreshCurrentLocationIfAuthorized() {
        guard manager.authorizationStatus == .authorizedAlways
                || manager.authorizationStatus == .authorizedWhenInUse else { return }
        isWorking = true
        requestedCurrentLocation = true
        manager.requestLocation()
    }

    func cancelLookup() {
        geocodingRequest?.cancel()
        reverseGeocodingRequest?.cancel()
        manager.stopUpdatingLocation()
        requestedCurrentLocation = false
        isWorking = false
        selection = nil
        errorMessage = nil
    }

    func resolve(zipCode: String) {
        guard zipCode.count == 5, zipCode.allSatisfy({ "0123456789".contains($0) }) else { return }
        cancelLookup()
        isWorking = true
        errorMessage = nil

        guard let request = MKGeocodingRequest(addressString: "\(zipCode), United States") else {
            isWorking = false
            errorMessage = "We couldn't resolve that ZIP code, but you can still continue."
            return
        }
        geocodingRequest?.cancel()
        geocodingRequest = request
        Task { [weak self] in
            guard let self else { return }
            do {
                let mapItems = try await request.mapItems
                guard !request.isCancelled else { return }
                guard let mapItem = mapItems.first else { throw LocationLookupError.noResult }
                self.apply(mapItem, fallbackPostalCode: zipCode)
            } catch {
                guard !request.isCancelled else { return }
                self.isWorking = false
                self.errorMessage = "We couldn't resolve that ZIP code, but you can still continue."
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard requestedCurrentLocation else { return }
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                isWorking = true
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                requestedCurrentLocation = false
                isWorking = false
                errorMessage = "Location access is unavailable. Enter your ZIP code instead."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            guard requestedCurrentLocation else { return }
            guard let request = MKReverseGeocodingRequest(location: location) else {
                requestedCurrentLocation = false
                isWorking = false
                errorMessage = "We found you, but couldn't name the location. Try a ZIP code."
                return
            }
            reverseGeocodingRequest?.cancel()
            reverseGeocodingRequest = request
            do {
                let mapItems = try await request.mapItems
                guard !request.isCancelled, requestedCurrentLocation else { return }
                guard let mapItem = mapItems.first else { throw LocationLookupError.noResult }
                self.apply(mapItem)
            } catch {
                guard !request.isCancelled else { return }
                requestedCurrentLocation = false
                isWorking = false
                errorMessage = "We found you, but couldn't name the location. Try a ZIP code."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard requestedCurrentLocation else { return }
            requestedCurrentLocation = false
            isWorking = false
            errorMessage = "We couldn't get your location. Enter your ZIP code instead."
        }
    }

    private func displayName(for mapItem: MKMapItem) -> String {
        mapItem.addressRepresentations?.cityWithContext
            ?? mapItem.address?.shortAddress
            ?? mapItem.name
            ?? "Selected location"
    }

    private func apply(_ mapItem: MKMapItem, fallbackPostalCode: String? = nil) {
        let coordinate = mapItem.location.coordinate
        isWorking = false
        postalCode = extractPostalCode(from: mapItem.address?.fullAddress) ?? fallbackPostalCode ?? ""
        resolvedLocation = displayName(for: mapItem)
        stateCode = USStateLookup.code(in: mapItem.addressRepresentations?.cityWithContext ?? resolvedLocation) ?? ""
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        selection = ResolvedDiscoveryLocation(
            postalCode: postalCode,
            name: resolvedLocation,
            stateCode: stateCode,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        requestedCurrentLocation = false
    }

    private func extractPostalCode(from address: String?) -> String? {
        guard let address,
              let range = address.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) else {
            return nil
        }
        return String(address[range].prefix(5))
    }
}

private enum LocationLookupError: Error {
    case noResult
}
