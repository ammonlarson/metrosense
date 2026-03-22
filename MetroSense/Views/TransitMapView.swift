import SwiftUI
import MapKit

struct TransitMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion?
    var nearestStation: MetroStation?
    var showsUserLocation: Bool = true
    var cameraResetToken: Int = 0

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        let config = MKStandardMapConfiguration()
        config.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        config.showsTraffic = false
        mapView.preferredConfiguration = config
        mapView.showsUserLocation = showsUserLocation
        mapView.showsCompass = true
        mapView.delegate = context.coordinator
        addMetroLineOverlays(to: mapView)
        return mapView
    }

    private func addMetroLineOverlays(to mapView: MKMapView) {
        for line in MetroLine.all {
            var coordinates = line.stations.map { $0.coordinate }
            if line.isCircular, let first = coordinates.first {
                coordinates.append(first)
            }
            let polyline = MetroLineOverlay(
                coordinates: &coordinates,
                count: coordinates.count
            )
            polyline.lineID = line.id
            mapView.addOverlay(polyline, level: .aboveRoads)
        }
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = showsUserLocation

        let forceReset = cameraResetToken != context.coordinator.lastResetToken
        if forceReset {
            context.coordinator.lastResetToken = cameraResetToken
        }

        if let region = region, forceReset || !mapView.region.isApproximatelyEqual(to: region) {
            let animated = context.coordinator.hasSetInitialRegion
            mapView.setRegion(region, animated: animated)
            context.coordinator.hasSetInitialRegion = true
        }

        updateStationAnnotation(mapView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func updateStationAnnotation(_ mapView: MKMapView, context: Context) {
        let existing = mapView.annotations.compactMap { $0 as? StationAnnotation }

        if let station = nearestStation {
            if let current = existing.first, current.stationName == station.name {
                current.coordinate = station.coordinate
                return
            }
            mapView.removeAnnotations(existing)
            let annotation = StationAnnotation(station: station)
            mapView.addAnnotation(annotation)
        } else {
            mapView.removeAnnotations(existing)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetInitialRegion = false
        var lastResetToken: Int = 0
        private static let pulseViewTag = 1001

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let stationAnnotation = annotation as? StationAnnotation else {
                return nil
            }

            let identifier = "StationAnnotation"
            let annotationView: MKAnnotationView
            if let reused = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                reused.annotation = stationAnnotation
                annotationView = reused
            } else {
                annotationView = MKAnnotationView(annotation: stationAnnotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = true
                annotationView.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
                configurePulseView(annotationView)
            }

            annotationView.accessibilityLabel = stationAnnotation.stationName

            return annotationView
        }

        private func configurePulseView(_ annotationView: MKAnnotationView) {
            annotationView.image = nil

            let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            container.tag = Self.pulseViewTag
            container.isUserInteractionEnabled = false

            let pulseCircle = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            pulseCircle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            pulseCircle.layer.cornerRadius = 22
            container.addSubview(pulseCircle)

            let whiteCircle = UIView(frame: CGRect(x: 12, y: 12, width: 20, height: 20))
            whiteCircle.backgroundColor = .white
            whiteCircle.layer.cornerRadius = 10
            container.addSubview(whiteCircle)

            let tramIcon = UIImageView(frame: CGRect(x: 15, y: 15, width: 14, height: 14))
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            tramIcon.image = UIImage(systemName: "tram.fill", withConfiguration: config)
            tramIcon.tintColor = .systemBlue
            tramIcon.contentMode = .scaleAspectFit
            container.addSubview(tramIcon)

            annotationView.addSubview(container)
            annotationView.centerOffset = CGPoint(x: 0, y: 0)

            startPulseAnimation(pulseCircle)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let lineOverlay = overlay as? MetroLineOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: lineOverlay)
            renderer.strokeColor = lineOverlay.lineID.mapColor
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        private func startPulseAnimation(_ view: UIView) {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 1.0
            animation.toValue = 1.6
            animation.duration = 1.5
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer.add(animation, forKey: "pulse")
        }
    }
}

// MARK: - Station Annotation

final class StationAnnotation: NSObject, MKAnnotation {
    let stationName: String
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(station: MetroStation) {
        self.stationName = station.name
        self.coordinate = station.coordinate
        super.init()
    }

    var title: String? { stationName }
}

// MARK: - Metro Line Overlay

final class MetroLineOverlay: MKPolyline {
    var lineID: MetroLine.LineID = .m1
}

extension MetroLine.LineID {
    var mapColor: UIColor {
        switch self {
        case .m1: return UIColor(red: 0.0, green: 0.65, blue: 0.31, alpha: 1.0)
        case .m2: return UIColor(red: 1.0, green: 0.78, blue: 0.0, alpha: 1.0)
        case .m3: return UIColor(red: 0.87, green: 0.15, blue: 0.17, alpha: 1.0)
        case .m4: return UIColor(red: 0.0, green: 0.63, blue: 0.87, alpha: 1.0)
        }
    }
}

// MARK: - Region Comparison

private extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, tolerance: Double = 0.0001) -> Bool {
        abs(center.latitude - other.center.latitude) < tolerance
            && abs(center.longitude - other.center.longitude) < tolerance
            && abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance
            && abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
}
