import MapKit
import SwiftUI

/// A MapKit bridge used because native annotation views provide reliable marker clustering.
struct ClusteredPlacesMap: UIViewRepresentable {
    let places: [Place]
    let focusCoordinate: CLLocationCoordinate2D?
    let focusState: String?
    let focusRequestID: UUID
    @Binding var selectedPlaceID: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.placeReuseIdentifier
        )
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.clusterReuseIdentifier
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.replaceAnnotationsIfNeeded(on: mapView)

        if !context.coordinator.hasAppliedInitialFocus {
            context.coordinator.hasAppliedInitialFocus = true
            context.coordinator.focus(on: mapView, animated: false)
            context.coordinator.lastFocusRequestID = focusRequestID
        } else if context.coordinator.lastFocusRequestID != focusRequestID {
            context.coordinator.lastFocusRequestID = focusRequestID
            context.coordinator.focus(on: mapView, animated: true)
        }

        if let selectedPlaceID,
           let annotation = context.coordinator.annotationsByID[selectedPlaceID],
           !mapView.selectedAnnotations.contains(where: { ($0 as? PathlyPlaceAnnotation)?.placeID == selectedPlaceID }) {
            mapView.selectAnnotation(annotation, animated: true)
        } else if selectedPlaceID == nil {
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: true) }
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        static let placeReuseIdentifier = "PathlyPlaceMarker"
        static let clusterReuseIdentifier = "PathlyPlaceCluster"

        var parent: ClusteredPlacesMap
        fileprivate var annotationsByID: [String: PathlyPlaceAnnotation] = [:]
        var loadedPlaceIDs: Set<String> = []
        var hasAppliedInitialFocus = false
        var lastFocusRequestID: UUID?

        init(parent: ClusteredPlacesMap) {
            self.parent = parent
        }

        func replaceAnnotationsIfNeeded(on mapView: MKMapView) {
            let validPlaces = parent.places.filter { $0.latitude != nil && $0.longitude != nil }
            let newIDs = Set(validPlaces.map(\.id))
            guard newIDs != loadedPlaceIDs else { return }

            mapView.removeAnnotations(Array(annotationsByID.values))
            annotationsByID = Dictionary(uniqueKeysWithValues: validPlaces.compactMap { place in
                guard let latitude = place.latitude, let longitude = place.longitude else { return nil }
                let annotation = PathlyPlaceAnnotation(
                    placeID: place.id,
                    title: place.name,
                    subtitle: [place.placeType.rawValue, place.city, place.state]
                        .compactMap { $0 }
                        .joined(separator: " · "),
                    state: place.state,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                )
                return (place.id, annotation)
            })
            loadedPlaceIDs = newIDs
            mapView.addAnnotations(Array(annotationsByID.values))
        }

        func focus(on mapView: MKMapView, animated: Bool) {
            if let coordinate = parent.focusCoordinate,
               CLLocationCoordinate2DIsValid(coordinate) {
                let region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 2.4, longitudeDelta: 2.4)
                )
                mapView.setRegion(region, animated: animated)
                return
            }

            if let state = parent.focusState {
                let stateAnnotations = annotationsByID.values.filter { $0.state == state }
                if !stateAnnotations.isEmpty {
                    mapView.showAnnotations(stateAnnotations, animated: animated)
                    return
                }
            }

            let annotations = Array(annotationsByID.values)
            if !annotations.isEmpty { mapView.showAnnotations(annotations, animated: animated) }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.clusterReuseIdentifier,
                    for: cluster
                ) as? MKMarkerAnnotationView
                view?.annotation = cluster
                view?.markerTintColor = UIColor(red: 0.000, green: 0.455, blue: 0.585, alpha: 1)
                view?.glyphText = cluster.memberAnnotations.count.formatted()
                view?.glyphTintColor = .white
                view?.displayPriority = .required
                view?.canShowCallout = false
                return view
            }

            guard annotation is PathlyPlaceAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Self.placeReuseIdentifier,
                for: annotation
            ) as? MKMarkerAnnotationView
            view?.annotation = annotation
            view?.markerTintColor = UIColor(red: 0.000, green: 0.610, blue: 0.735, alpha: 1)
            view?.glyphImage = UIImage(systemName: "sparkles")
            view?.glyphTintColor = .white
            view?.clusteringIdentifier = "pathly-place"
            view?.displayPriority = .defaultHigh
            view?.canShowCallout = false
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let cluster = annotation as? MKClusterAnnotation {
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
                mapView.deselectAnnotation(cluster, animated: false)
                return
            }
            guard let placeAnnotation = annotation as? PathlyPlaceAnnotation else { return }
            parent.selectedPlaceID = placeAnnotation.placeID
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            guard let placeAnnotation = annotation as? PathlyPlaceAnnotation,
                  parent.selectedPlaceID == placeAnnotation.placeID,
                  !mapView.selectedAnnotations.contains(where: { $0 is PathlyPlaceAnnotation }) else { return }
            parent.selectedPlaceID = nil
        }
    }
}

fileprivate final class PathlyPlaceAnnotation: NSObject, MKAnnotation {
    let placeID: String
    let title: String?
    let subtitle: String?
    let state: String?
    let coordinate: CLLocationCoordinate2D

    init(
        placeID: String,
        title: String,
        subtitle: String,
        state: String?,
        coordinate: CLLocationCoordinate2D
    ) {
        self.placeID = placeID
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.coordinate = coordinate
    }
}
