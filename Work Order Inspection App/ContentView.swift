import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        NavigationStack {
            if appEnvironment.isAuthenticated {
                SiteSelectionView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppEnvironment(apiClient: MockSalesforceAPIClient()))
        .modelContainer(for: [
            SiteEntity.self,
            WorkOrderEntity.self,
            WorkTaskEntity.self,
            WorkTaskStepEntity.self,
            LocalStepDraftEntity.self,
            PendingPhotoUploadEntity.self
        ], inMemory: true)
}
