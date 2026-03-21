import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MetroViewModel()
    @State private var showingSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapContentView(viewModel: viewModel)

            settingsButton
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                settings: viewModel.settings,
                currentLocation: viewModel.currentLocation,
                currentSpeed: viewModel.currentSpeed,
                lastMovementNotificationTime: viewModel.lastMovementNotificationTime,
                onSettingsChanged: { newSettings in
                    newSettings.save()
                    viewModel.settings = newSettings
                }
            )
        }
        .onAppear {
            viewModel.start()
        }
    }

    private var settingsButton: some View {
        GeometryReader { proxy in
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .position(
                x: proxy.size.width - 32,
                y: proxy.safeAreaInsets.top + 24
            )
        }
    }
}

#Preview {
    ContentView()
}
