import SwiftUI
import MapKit

struct MapContentView: View {
    @ObservedObject var viewModel: MetroViewModel
    @Binding var showingSettings: Bool
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pulseScale: CGFloat = 1.0
    @State private var lastCameraUpdateLocation: CLLocation?

    @AppStorage("mapOverlayExpanded") private var overlayExpanded: Bool = true
    @State private var dragOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var bottomSafeAreaInset: CGFloat = 0

    /// Height of the collapsed portion that stays visible (drag handle + status icon only).
    private static let collapsedVisibleHeight: CGFloat = 130
    /// Full overlay card height.
    private static let overlayFullHeight: CGFloat = 340
    /// Threshold to trigger a snap when dragging.
    private static let snapThreshold: CGFloat = 80

    /// Total overlay height including bottom safe area inset.
    private var totalOverlayHeight: CGFloat {
        Self.overlayFullHeight + bottomSafeAreaInset
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                mapLayer
                if viewModel.isUsingDegradedLocation {
                    degradedBanner
                }
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        resetCameraButton
                    }
                    .padding(.horizontal, 16)
                    overlayCard
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .onAppear {
                screenHeight = geometry.size.height
                bottomSafeAreaInset = geometry.safeAreaInsets.bottom
            }
            .onChange(of: geometry.size.height) {
                screenHeight = geometry.size.height
                bottomSafeAreaInset = geometry.safeAreaInsets.bottom
            }
            .onChange(of: geometry.safeAreaInsets.bottom) {
                bottomSafeAreaInset = geometry.safeAreaInsets.bottom
            }
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
        .onChange(of: overlayExpanded) {
            updateCamera()
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

    private var metroStatusImage: String {
        switch viewModel.tripState {
        case .idle, .atStation:
            return "MetroNo"
        case .onMetro, .arrived:
            return "MetroYes"
        }
    }

    private var overlayCard: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height
            let collapseOffset = max(fullHeight - Self.collapsedVisibleHeight, 0)
            let baseOffset = overlayExpanded ? 0 : collapseOffset
            let clampedDrag = min(max(dragOffset + baseOffset, 0), collapseOffset)

            VStack(spacing: 0) {
                overlayHeader

                Image(metroStatusImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Text(tripStateLabel)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)

                Text(tripStateDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal)

                HStack {
                    Image(systemName: "speedometer")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Speed")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f km/h", viewModel.speedKMH))
                        .font(.title3.monospacedDigit().bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .padding(.horizontal)

                HStack {
                    Image(systemName: "tram.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Nearest Station")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(nearestStationLabel)
                            .font(.title3.bold())
                        Text(nearestStationDistance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .padding(.bottom, bottomSafeAreaInset)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .offset(y: clampedDrag)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let projected = value.predictedEndTranslation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if projected > Self.snapThreshold {
                                overlayExpanded = false
                            } else if projected < -Self.snapThreshold {
                                overlayExpanded = true
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .clipped()
        .frame(height: totalOverlayHeight)
    }

    private var overlayHeader: some View {
        ZStack {
            dragHandle
            HStack {
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(10)
                }
            }
            .padding(.trailing, 8)
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary.opacity(0.5))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
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

    /// The vertical offset applied to the overlay card content, mirrored here
    /// so the reset button tracks the overlay during drag and snap animations.
    private var overlayOffset: CGFloat {
        let collapseOffset = max(totalOverlayHeight - Self.collapsedVisibleHeight, 0)
        let baseOffset = overlayExpanded ? 0 : collapseOffset
        return min(max(dragOffset + baseOffset, 0), collapseOffset)
    }

    private var resetCameraButton: some View {
        Button {
            lastCameraUpdateLocation = nil
            updateCamera()
        } label: {
            Image(systemName: "location.fill")
                .font(.body)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .offset(y: overlayOffset)
    }

    // MARK: - Camera

    /// Fraction of the screen height occupied by the overlay in its current state.
    private var overlayScreenFraction: CGFloat {
        guard screenHeight > 0 else { return 0 }
        let visibleOverlayHeight = overlayExpanded
            ? totalOverlayHeight
            : Self.collapsedVisibleHeight
        return visibleOverlayHeight / screenHeight
    }

    private func updateCamera() {
        guard let userLocation = viewModel.currentLocation else { return }

        let userCoord = userLocation.coordinate
        let overlayFraction = overlayScreenFraction
        // The visible area above the overlay is (1 - overlayFraction) of the screen.
        // Scale the map span so the content fits within that visible portion, then
        // shift the center southward so markers render in the upper visible area.
        let visibleFraction = max(1 - overlayFraction, 0.3)

        if let station = viewModel.nearestStation {
            let minLat = min(userCoord.latitude, station.coordinate.latitude)
            let maxLat = max(userCoord.latitude, station.coordinate.latitude)
            let minLon = min(userCoord.longitude, station.coordinate.longitude)
            let maxLon = max(userCoord.longitude, station.coordinate.longitude)

            let latMargin = max((maxLat - minLat) * 0.4, 0.002)
            let lonMargin = max((maxLon - minLon) * 0.4, 0.002)

            let contentLat = (maxLat - minLat) + latMargin * 2
            let contentLon = (maxLon - minLon) + lonMargin * 2

            // Expand the latitude span so the content occupies only the visible portion.
            let mapSpanLat = contentLat / visibleFraction
            let latOffset = mapSpanLat * overlayFraction / 2

            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2 - latOffset,
                    longitude: (minLon + maxLon) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: mapSpanLat,
                    longitudeDelta: contentLon
                )
            )
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        } else {
            let contentLat = 0.01
            let mapSpanLat = contentLat / visibleFraction
            let latOffset = mapSpanLat * overlayFraction / 2

            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: userCoord.latitude - latOffset,
                            longitude: userCoord.longitude
                        ),
                        span: MKCoordinateSpan(latitudeDelta: mapSpanLat, longitudeDelta: contentLat)
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
    MapContentView(viewModel: MetroViewModel(), showingSettings: .constant(false))
}
