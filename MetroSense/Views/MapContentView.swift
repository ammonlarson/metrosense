import SwiftUI
import MapKit

struct MapContentView: View {
    @ObservedObject var viewModel: MetroViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pulseScale: CGFloat = 1.0
    @State private var lastCameraUpdateLocation: CLLocation?

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            overlayCard
            if viewModel.isUsingDegradedLocation {
                degradedBanner
            }
            resetCameraButton
        }
        .onChange(of: viewModel.nearestStation) {
            updateCamera()
        }
        .onChange(of: viewModel.currentLocation?.coordinate.latitude) {
            updateCameraIfNeeded()
        }
        .onChange(of: viewModel.currentLocation?.coordinate.longitude) {
            updateCameraIfNeeded()
        }
    }

    private func updateCameraIfNeeded() {
        guard let current = viewModel.currentLocation else { return }
        if let last = lastCameraUpdateLocation, current.distance(from: last) < 50 {
            return
        }
        lastCameraUpdateLocation = current
        updateCamera()
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if let station = viewModel.nearestStation {
                Annotation(station.name, coordinate: station.coordinate) {
                    stationAnnotationView
                }
            }
        }
        .mapStyle(.imagery(elevation: .flat))
        .mapControls {
            MapCompass()
        }
        .ignoresSafeArea()
    }

    private var stationAnnotationView: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)

            Image(systemName: "tram.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.blue)
        }
        .onAppear {
            pulseScale = 1.6
        }
    }

    // MARK: - Overlay Card

    private var overlayCard: some View {
        VStack(spacing: 0) {
            // Watermark
            watermark

            // Status
            VStack(spacing: 4) {
                Text(tripStateLabel)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(tripStateDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal)

            // Info rows
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "tram.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f km/h", viewModel.speedKMH))
                            .font(.subheadline.monospacedDigit().bold())
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(nearestStationLabel) · \(nearestStationDistance)")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    // MARK: - Watermark

    private var watermark: some View {
        HStack(spacing: 4) {
            Image(systemName: "tram.circle")
                .font(.caption2)
            Text("METRO")
                .font(.caption2.bold())
                .kerning(2)
        }
        .foregroundStyle(.secondary.opacity(0.4))
        .padding(.bottom, 8)
    }

    // MARK: - Degraded Banner

    private var degradedBanner: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "location.slash.circle.fill")
                    .foregroundStyle(.yellow)
                Text("Degraded GPS accuracy")
                    .font(.footnote.bold())
                Spacer()
                if let accuracy = viewModel.currentLocation?.horizontalAccuracy {
                    Text("±\(Int(accuracy))m")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Reset Camera Button

    private var resetCameraButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    lastCameraUpdateLocation = nil
                    updateCamera()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.body)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }

    }

    // MARK: - Camera

    private func updateCamera() {
        guard let userLocation = viewModel.currentLocation else { return }

        let userCoord = userLocation.coordinate

        if let station = viewModel.nearestStation {
            let minLat = min(userCoord.latitude, station.coordinate.latitude)
            let maxLat = max(userCoord.latitude, station.coordinate.latitude)
            let minLon = min(userCoord.longitude, station.coordinate.longitude)
            let maxLon = max(userCoord.longitude, station.coordinate.longitude)

            let latMargin = max((maxLat - minLat) * 0.4, 0.002)
            let lonMargin = max((maxLon - minLon) * 0.4, 0.002)

            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: (maxLat - minLat) + latMargin * 2,
                    longitudeDelta: (maxLon - minLon) + lonMargin * 2
                )
            )
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: userCoord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    private var tripStateLabel: String {
        switch viewModel.tripState {
        case .idle:
            return "Not on Metro"
        case .atStation(let s):
            return "At \(s.name)"
        case .onMetro(let l, _, _):
            return "On \(l.rawValue)"
        case .arrived(_, _, let to):
            return "Arrived at \(to.name)"
        }
    }

    private var tripStateDetail: String {
        switch viewModel.tripState {
        case .idle:
            return "Move to a station to begin detection"
        case .atStation(let s):
            let lines = s.lines.map { $0.rawValue }.joined(separator: ", ")
            return "Lines: \(lines)"
        case .onMetro(let l, let from, let speed):
            return "\(l.rawValue) from \(from.name) · \(String(format: "%.0f", speed * 3.6)) km/h"
        case .arrived(let l, let from, let to):
            return "\(l.rawValue): \(from.name) → \(to.name)"
        }
    }

    private var nearestStationLabel: String {
        viewModel.nearestStation?.name ?? "Station"
    }

    private var nearestStationDistance: String {
        guard let distance = viewModel.nearestStationDistance else { return "—" }
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}

#Preview {
    MapContentView(viewModel: MetroViewModel())
}
