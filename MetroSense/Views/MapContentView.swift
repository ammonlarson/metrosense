import SwiftUI
import MapKit

struct MapContentView: View {
    @ObservedObject var viewModel: MetroViewModel
    var onSettingsChanged: (NotificationSettings) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pulseScale: CGFloat = 1.0
    @State private var lastCameraUpdateLocation: CLLocation?

    @AppStorage("mapOverlayExpanded") private var overlayExpanded: Bool = true
    @State private var settingsVisible: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var bottomSafeAreaInset: CGFloat = 0

    @State private var showingProximitySettings: Bool = false
    @State private var showingMovementSettings: Bool = false
    @State private var showGearButton: Bool = true
    @State private var testResult: NotificationTestResult?
    @State private var isTesting: Bool = false
    @State private var testProgress: CGFloat = 0
    @State private var testRunId: Int = 0

    private let allStationNames: [String]

    /// Height of the collapsed portion that stays visible (drag handle + status icon only).
    private static let collapsedVisibleHeight: CGFloat = 130
    /// Full overlay card height.
    private static let overlayFullHeight: CGFloat = 340
    /// Overlay height when settings categories are visible.
    private static let settingsOverlayHeight: CGFloat = 700
    /// Threshold to trigger a snap when dragging.
    private static let snapThreshold: CGFloat = 80

    init(viewModel: MetroViewModel, onSettingsChanged: @escaping (NotificationSettings) -> Void) {
        self.viewModel = viewModel
        self.onSettingsChanged = onSettingsChanged
        var seen = Set<String>()
        var names: [String] = []
        for line in MetroLine.all {
            for station in line.stations {
                if seen.insert(station.name).inserted {
                    names.append(station.name)
                }
            }
        }
        allStationNames = names.sorted()
    }

    /// Total overlay height (background extends into safe area via ignoresSafeArea).
    private var totalOverlayHeight: CGFloat {
        settingsVisible ? Self.settingsOverlayHeight : Self.overlayFullHeight
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
        .onChange(of: settingsVisible) {
            if !settingsVisible {
                testResult = nil
                isTesting = false
            }
            updateCamera()
        }
        .sheet(isPresented: $showingProximitySettings) {
            NavigationStack {
                ProximitySettingsView(
                    settings: Binding(
                        get: { viewModel.settings },
                        set: { onSettingsChanged($0) }
                    ),
                    allStationNames: allStationNames
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showingProximitySettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title2)
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
        .sheet(isPresented: $showingMovementSettings) {
            NavigationStack {
                MovementSettingsView(
                    settings: Binding(
                        get: { viewModel.settings },
                        set: { onSettingsChanged($0) }
                    ),
                    allStationNames: allStationNames
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showingMovementSettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title2)
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
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

                if settingsVisible {
                    settingsCategories
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    testSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                (colorScheme == .dark ? Color.black : Color.white)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .ignoresSafeArea(edges: .bottom)
            }
            .offset(y: clampedDrag)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let projected = value.predictedEndTranslation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if settingsVisible {
                                if projected > Self.snapThreshold {
                                    settingsVisible = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        showGearButton = true
                                    }
                                }
                            } else if overlayExpanded {
                                if projected > Self.snapThreshold {
                                    overlayExpanded = false
                                } else if projected < -Self.snapThreshold {
                                    showGearButton = false
                                    settingsVisible = true
                                }
                            } else {
                                if projected < -Self.snapThreshold {
                                    overlayExpanded = true
                                }
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: totalOverlayHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settingsVisible)
    }

    private var overlayHeader: some View {
        ZStack {
            dragHandle
            HStack {
                Spacer()
                if settingsVisible {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            settingsVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showGearButton = true
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }
                    .accessibilityLabel("Close settings")
                    .transition(.identity)
                } else if showGearButton {
                    Button {
                        showGearButton = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if !overlayExpanded {
                                overlayExpanded = true
                            }
                            settingsVisible = true
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }
                    .accessibilityLabel("Settings")
                    .transition(.identity)
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

    // MARK: - Settings Categories

    private var proximityStatusText: String {
        viewModel.settings.proximityEnabled ? "On — \(Int(viewModel.settings.proximityRadius))m radius" : "Off"
    }

    private var movementStatusText: String {
        viewModel.settings.movementEnabled ? "On — \(Int(viewModel.settings.minimumSpeedKMH))–\(Int(viewModel.settings.maximumSpeedKMH)) km/h" : "Off"
    }

    private var settingsCategories: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal)

            Text("Settings")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            Button {
                showingProximitySettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "location.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Metro Proximity")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(proximityStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()
                .padding(.horizontal)

            Button {
                showingMovementSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Movement Detection")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(movementStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal)

            Text("Test")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            Button {
                runTest()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text("Test Notifications Now")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .disabled(!viewModel.settings.isValid || isTesting)

            if isTesting {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * testProgress)
                            .animation(.linear(duration: 1.5), value: testProgress)
                    }
                }
                .id(testRunId)
                .frame(height: 12)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else if let result = testResult {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: result.proximityWouldFire ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.proximityWouldFire ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.proximityWouldFire ? "Proximity: Would fire" : "Proximity: Would not fire")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(result.proximityDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: result.movementWouldFire ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.movementWouldFire ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.movementWouldFire ? "Movement: Would fire" : "Movement: Would not fire")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(result.movementDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Text("Check whether a notification would fire right now based on your current location and speed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
    }

    private func runTest() {
        testResult = nil
        testProgress = 0
        testRunId += 1
        isTesting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            testProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            let result = NotificationTestResult.evaluate(
                settings: viewModel.settings,
                location: viewModel.currentLocation,
                speed: viewModel.currentSpeed,
                lastMovementNotificationTime: viewModel.lastMovementNotificationTime
            )
            withAnimation {
                testResult = result
                isTesting = false
            }
        }
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
        let visibleOverlayHeight: CGFloat
        if settingsVisible {
            visibleOverlayHeight = Self.settingsOverlayHeight + bottomSafeAreaInset
        } else if overlayExpanded {
            visibleOverlayHeight = Self.overlayFullHeight + bottomSafeAreaInset
        } else {
            visibleOverlayHeight = Self.collapsedVisibleHeight
        }
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
    MapContentView(viewModel: MetroViewModel(), onSettingsChanged: { _ in })
}
