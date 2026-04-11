import SwiftUI
import MapKit

struct MapContentView: View {
    @ObservedObject var viewModel: MetroViewModel
    var onSettingsChanged: (NotificationSettings) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .title2) private var statusImageHeight: CGFloat = 100
    @ScaledMetric(relativeTo: .body) private var sectionVerticalPadding: CGFloat = 14
    @State private var mapRegion: MKCoordinateRegion?
    @State private var lastCameraUpdateLocation: CLLocation?
    @State private var cameraResetToken: Int = 0
    @State private var isAutoFollowEnabled: Bool = true

    @AppStorage("mapOverlayExpanded") private var overlayExpanded: Bool = true
    @State private var settingsVisible: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    @State private var screenWidth: CGFloat = 0
    @State private var bottomSafeAreaInset: CGFloat = 0

    @State private var showingProximitySettings: Bool = false
    @State private var showingMovementSettings: Bool = false
    @State private var showingTestNotifications: Bool = false
    @State private var showingRejsekortSettings: Bool = false
    @State private var showSettingsIcon: Bool = true

    private let allStationNames: [String]

    /// Minimum height always kept visible for the map above the overlay.
    private static let minimumMapHeight: CGFloat = 120
    /// Threshold to trigger a snap when dragging.
    private static let collapseThreshold: CGFloat = 40
    private static let expandThreshold: CGFloat = 120
    /// Base heights used as starting points before screen-relative capping.
    private static let baseCollapsedHeight: CGFloat = 130
    private static let baseFullHeight: CGFloat = 370
    private static let baseSettingsHeight: CGFloat = 600

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

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    /// Base heights for landscape mode.
    private static let baseLandscapeCollapsedHeight: CGFloat = 100
    private static let baseLandscapeFullHeight: CGFloat = 220

    /// Maximum overlay height that still leaves enough map visible.
    private var maxOverlayHeight: CGFloat {
        guard screenHeight > 0 else { return 600 }
        return screenHeight - Self.minimumMapHeight
    }

    private var currentCollapsedHeight: CGFloat {
        let base = isLandscape ? Self.baseLandscapeCollapsedHeight : Self.baseCollapsedHeight
        return min(base, maxOverlayHeight)
    }

    private static let rejsekortButtonHeight: CGFloat = 44

    private var currentFullHeight: CGFloat {
        var base = isLandscape ? Self.baseLandscapeFullHeight : Self.baseFullHeight
        if showRejsekortShortcut {
            base += Self.rejsekortButtonHeight
        }
        return min(base, maxOverlayHeight)
    }

    /// In landscape, settings replace the main content instead of appending
    /// below it, so we reuse the full overlay height rather than growing taller.
    private var currentSettingsHeight: CGFloat {
        let base = isLandscape ? Self.baseLandscapeFullHeight : Self.baseSettingsHeight
        return min(base, maxOverlayHeight)
    }

    /// Total overlay height (background extends into safe area via ignoresSafeArea).
    private var totalOverlayHeight: CGFloat {
        settingsVisible ? currentSettingsHeight : currentFullHeight
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                mapLayer
                if viewModel.isSignalLost {
                    signalLostBanner
                } else if viewModel.isUsingDegradedLocation {
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
                screenWidth = geometry.size.width
                bottomSafeAreaInset = geometry.safeAreaInsets.bottom
            }
            .onChange(of: geometry.size.height) {
                screenHeight = geometry.size.height
                screenWidth = geometry.size.width
                bottomSafeAreaInset = geometry.safeAreaInsets.bottom
            }
            .onChange(of: geometry.safeAreaInsets.bottom) {
                bottomSafeAreaInset = geometry.safeAreaInsets.bottom
            }
        }
        .onChange(of: viewModel.nearestStation) {
            if isAutoFollowEnabled { updateCamera() }
        }
        .onChange(of: viewModel.currentLocation?.coordinate.latitude) {
            if isAutoFollowEnabled { updateCameraIfNeeded() }
        }
        .onChange(of: viewModel.currentLocation?.coordinate.longitude) {
            if isAutoFollowEnabled { updateCameraIfNeeded() }
        }
        .onChange(of: overlayExpanded) {
            if isAutoFollowEnabled { updateCamera() }
        }
        .onChange(of: settingsVisible) {
            if isAutoFollowEnabled { updateCamera() }
        }
        .onChange(of: verticalSizeClass) {
            if isAutoFollowEnabled { updateCamera() }
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingProximitySettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.blue)
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingMovementSettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTestNotifications) {
            NavigationStack {
                TestNotificationsView(
                    settings: $viewModel.settings,
                    location: viewModel.currentLocation,
                    speed: viewModel.currentSpeed,
                    lastMovementNotificationTime: viewModel.lastMovementNotificationTime,
                    lastProximityNotificationTime: viewModel.lastProximityNotificationTime
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingTestNotifications = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
        .sheet(isPresented: $showingRejsekortSettings) {
            NavigationStack {
                RejsekortSettingsView(
                    settings: Binding(
                        get: { viewModel.settings },
                        set: { onSettingsChanged($0) }
                    )
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingRejsekortSettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.blue)
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
        TransitMapView(
            region: $mapRegion,
            nearestStation: viewModel.nearestStation,
            cameraResetToken: cameraResetToken,
            onUserInteraction: { isAutoFollowEnabled = false }
        )
        .ignoresSafeArea()
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
            let collapseOffset = max(fullHeight - currentCollapsedHeight, 0)
            let baseOffset = overlayExpanded ? 0 : collapseOffset
            let clampedDrag = min(max(dragOffset + baseOffset, 0), collapseOffset)

            VStack(spacing: 0) {
                overlayHeader

                Image(metroStatusImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: isLandscape ? min(statusImageHeight * 0.6, 80) : min(statusImageHeight, 140))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .padding(.top, 8)
                    .padding(.bottom, isLandscape ? 6 : 12)
                    .gesture(overlayDragGesture)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if isLandscape && settingsVisible {
                            settingsCategories
                                .transition(.opacity)
                        } else if isLandscape {
                            landscapeContent
                        } else {
                            portraitContent

                            if settingsVisible {
                                settingsCategories
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                (colorScheme == .dark ? Color.black : Color.white)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .ignoresSafeArea(edges: .bottom)
            }
            .offset(y: clampedDrag)
        }
        .frame(height: totalOverlayHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settingsVisible)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRejsekortShortcut)
    }

    // MARK: - Portrait Content

    private var portraitContent: some View {
        VStack(spacing: 0) {
            statusSection

            Divider()
                .padding(.horizontal)

            speedSection

            Divider()
                .padding(.horizontal)

            nearestStationSection
        }
    }

    // MARK: - Landscape Content

    private var landscapeContent: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                statusSection
            }
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.vertical, 8)

            VStack(spacing: 0) {
                speedSection

                Divider()
                    .padding(.horizontal)

                nearestStationSection
            }
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Content Sections

    private var statusSection: some View {
        VStack(spacing: 0) {
            Text(tripStateLabel)
                .font(isLandscape ? .headline.bold() : .title2.bold())
                .foregroundStyle(.primary)
                .padding(.bottom, 4)

            Text(tripStateDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(isLandscape ? 2 : nil)
                .padding(.horizontal)
                .padding(.bottom, showRejsekortShortcut ? 8 : (isLandscape ? 8 : 16))

            if showRejsekortShortcut {
                rejsekortButton
                    .padding(.bottom, isLandscape ? 8 : 16)
            }
        }
    }

    private var showRejsekortShortcut: Bool {
        guard viewModel.settings.rejsekortEnabled else { return false }
        if viewModel.settings.alwaysShowRejsekortPill { return true }
        switch viewModel.tripState {
        case .atStation:
            return viewModel.settings.proximityShowRejsekortPill
        case .onMetro:
            return viewModel.settings.movementShowRejsekortPill
        case .idle, .arrived:
            return false
        }
    }

    private var rejsekortButton: some View {
        Button {
            openURL(NotificationService.rejsekortAppURL) { accepted in
                if !accepted {
                    openURL(NotificationService.rejsekortStoreURL)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill")
                    .font(.subheadline)
                Text("Open Rejsekort")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.blue, in: Capsule())
        }
        .accessibilityLabel("Open Rejsekort app")
    }

    private var speedSection: some View {
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
        .padding(.vertical, sectionVerticalPadding)
    }

    private var nearestStationSection: some View {
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
        .padding(.vertical, sectionVerticalPadding)
    }

    private var overlayHeader: some View {
        ZStack {
            dragHandle
            HStack {
                Spacer()
                if showSettingsIcon {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if !overlayExpanded {
                                overlayExpanded = true
                            }
                            settingsVisible = true
                        } completion: {
                            showSettingsIcon = false
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                    .transition(.identity)
                } else {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            settingsVisible = false
                        } completion: {
                            showSettingsIcon = true
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close settings")
                    .transition(.identity)
                }
            }
            .padding(.trailing, 8)
        }
        .gesture(overlayDragGesture)
    }

    private var overlayDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if settingsVisible {
                        if projected > Self.collapseThreshold {
                            settingsVisible = false
                        }
                    } else if overlayExpanded {
                        if projected > Self.collapseThreshold {
                            overlayExpanded = false
                        } else if projected < -Self.expandThreshold {
                            settingsVisible = true
                        }
                    } else {
                        if projected < -Self.expandThreshold {
                            overlayExpanded = true
                        }
                    }
                    dragOffset = 0
                } completion: {
                    showSettingsIcon = !settingsVisible
                }
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
                .padding(.top, isLandscape ? 6 : 12)
                .padding(.bottom, isLandscape ? 2 : 4)

            settingsCategoryRows
        }
    }

    private var settingsCategoryRows: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "location.circle",
                title: "Metro Proximity",
                subtitle: proximityStatusText
            ) {
                showingProximitySettings = true
            }

            Divider()
                .padding(.horizontal)

            settingsRow(
                icon: "figure.run",
                title: "Movement Detection",
                subtitle: movementStatusText
            ) {
                showingMovementSettings = true
            }

            Divider()
                .padding(.horizontal)

            settingsRow(
                icon: "bell.badge",
                title: "Notifications",
                subtitle: "Cooldown & test alerts"
            ) {
                showingTestNotifications = true
            }

            Divider()
                .padding(.horizontal)

            settingsRow(
                icon: "creditcard",
                title: "Rejsekort",
                subtitle: rejsekortStatusText
            ) {
                showingRejsekortSettings = true
            }
        }
    }

    private var rejsekortStatusText: String {
        viewModel.settings.rejsekortEnabled ? "On" : "Off"
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                if isLandscape {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isLandscape ? 6 : 10)
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
            .frame(maxWidth: isLandscape ? 400 : .infinity)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var signalLostBanner: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(.red)
                Text("GPS signal unavailable")
                    .font(.footnote.bold())
                Spacer()
                Text("Searching…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .frame(maxWidth: isLandscape ? 400 : .infinity)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Reset Camera Button

    /// The vertical offset applied to the overlay card content, mirrored here
    /// so the reset button tracks the overlay during drag and snap animations.
    private var overlayOffset: CGFloat {
        let collapseOffset = max(totalOverlayHeight - currentCollapsedHeight, 0)
        let baseOffset = overlayExpanded ? 0 : collapseOffset
        return min(max(dragOffset + baseOffset, 0), collapseOffset)
    }

    private var resetCameraButton: some View {
        Button {
            isAutoFollowEnabled = true
            lastCameraUpdateLocation = nil
            cameraResetToken += 1
            updateCamera()
        } label: {
            Image(systemName: isAutoFollowEnabled ? "location.fill" : "location")
                .font(.body)
                .foregroundStyle(isAutoFollowEnabled ? .blue : .secondary)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .offset(y: overlayOffset)
        .accessibilityLabel(isAutoFollowEnabled ? "Following location" : "Recenter map")
        .animation(.easeInOut(duration: 0.2), value: isAutoFollowEnabled)
    }

    // MARK: - Camera

    /// Fraction of the screen height occupied by the overlay in its current state.
    private var overlayScreenFraction: CGFloat {
        guard screenHeight > 0 else { return 0 }
        let visibleOverlayHeight: CGFloat
        if settingsVisible {
            visibleOverlayHeight = currentSettingsHeight + bottomSafeAreaInset
        } else if overlayExpanded {
            visibleOverlayHeight = currentFullHeight + bottomSafeAreaInset
        } else {
            visibleOverlayHeight = currentCollapsedHeight
        }
        return visibleOverlayHeight / screenHeight
    }

    private func updateCamera() {
        guard let userLocation = viewModel.currentLocation else { return }

        let userCoord = userLocation.coordinate
        let overlayFraction = overlayScreenFraction
        let visibleFraction = max(1 - overlayFraction, 0.3)
        let aspectRatio = screenWidth > 0 && screenHeight > 0 ? screenWidth / screenHeight : 1.0

        if let station = viewModel.nearestStation {
            let minLat = min(userCoord.latitude, station.coordinate.latitude)
            let maxLat = max(userCoord.latitude, station.coordinate.latitude)
            let minLon = min(userCoord.longitude, station.coordinate.longitude)
            let maxLon = max(userCoord.longitude, station.coordinate.longitude)

            let latMargin = max((maxLat - minLat) * 0.4, 0.002)
            let lonMargin = max((maxLon - minLon) * 0.4, isLandscape ? 0.004 : 0.002)

            let contentLat = (maxLat - minLat) + latMargin * 2
            let contentLon = max((maxLon - minLon) + lonMargin * 2, contentLat * aspectRatio)

            let mapSpanLat = contentLat / visibleFraction
            let latOffset = mapSpanLat * overlayFraction / 2

            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2 - latOffset,
                    longitude: (minLon + maxLon) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: mapSpanLat,
                    longitudeDelta: contentLon
                )
            )
        } else {
            let contentLat = 0.01
            let contentLon = contentLat * aspectRatio
            let mapSpanLat = contentLat / visibleFraction
            let latOffset = mapSpanLat * overlayFraction / 2

            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: userCoord.latitude - latOffset,
                    longitude: userCoord.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: mapSpanLat, longitudeDelta: contentLon)
            )
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
        if viewModel.isSignalLost {
            switch viewModel.tripState {
            case .idle:
                return "GPS signal unavailable"
            case .atStation:
                return "GPS signal lost — last known position"
            case .onMetro(let l, let from, _):
                return "\(l.rawValue) from \(from.name) · GPS signal lost"
            case .arrived(let l, let from, let to):
                return "\(l.rawValue): \(from.name) → \(to.name)"
            }
        }
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
