import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MetroViewModel()

    var body: some View {
        MapContentView(viewModel: viewModel) { newSettings in
            viewModel.settings = newSettings
            if newSettings.isValid {
                newSettings.save()
            }
        }
        .onAppear {
            viewModel.start()
        }
    }
}

#Preview {
    ContentView()
}
