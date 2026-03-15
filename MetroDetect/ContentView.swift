import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MetroViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isUsingDegradedLocation {
                    degradedLocationBanner
                }
                statusCard
                speedCard
                stationCard
            }
            .padding()
            .navigationTitle("MetroDetect")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    settings: viewModel.settings,
                    currentLocation: viewModel.currentLocation,
                    currentSpeed: viewModel.currentSpeed
                ) { newSettings in
                    newSettings.save()
                    viewModel.settings = newSettings
                }
            }
        }
        .onAppear {
            viewModel.start()
        }
    }

    // MARK: - Subviews

    private var degradedLocationBanner: some View {
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
            } else {
                Text("Location may be imprecise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusCard: some View {
        VStack(spacing: 8) {
            Image(systemName: tripStateIcon)
                .font(.system(size: 56))
                .foregroundStyle(tripStateColor)
            Text(tripStateLabel)
                .font(.title2.bold())
            Text(tripStateDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(tripStateColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private var speedCard: some View {
        HStack {
            Label("Speed", systemImage: "speedometer")
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.0f km/h", viewModel.speedKMH))
                .font(.title3.monospacedDigit())
                .bold()
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var stationCard: some View {
        HStack {
            Label("Nearest Station", systemImage: "tram.fill")
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.nearestStation?.name ?? "—")
                .font(.subheadline.bold())
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var tripStateIcon: String {
        switch viewModel.tripState {
        case .idle:               return "location.slash"
        case .atStation:          return "tram.fill.tunnel"
        case .onMetro:            return "tram.fill"
        case .arrived:            return "mappin.circle.fill"
        }
    }

    private var tripStateColor: Color {
        switch viewModel.tripState {
        case .idle:      return .gray
        case .atStation: return .blue
        case .onMetro:   return .green
        case .arrived:   return .orange
        }
    }

    private var tripStateLabel: String {
        switch viewModel.tripState {
        case .idle:               return "Not on Metro"
        case .atStation(let s):   return "At \(s.name)"
        case .onMetro(let l, _, _): return "On \(l.rawValue)"
        case .arrived(_, _, let to): return "Arrived at \(to.name)"
        }
    }

    private var tripStateDetail: String {
        switch viewModel.tripState {
        case .idle:
            return "Move to a metro station to begin detection"
        case .atStation(let s):
            let lines = s.lines.map { $0.rawValue }.joined(separator: ", ")
            return "Lines: \(lines)"
        case .onMetro(let l, let from, let speed):
            return "\(l.rawValue) from \(from.name) · \(String(format: "%.0f", speed * 3.6)) km/h"
        case .arrived(let l, let from, let to):
            return "\(l.rawValue): \(from.name) → \(to.name)"
        }
    }
}

#Preview {
    ContentView()
}
