import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MetroViewModel()
    @State private var showingSettings = false

    var body: some View {
        MapContentView(viewModel: viewModel, showingSettings: $showingSettings)
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
}

#Preview {
    ContentView()
}
