import SwiftUI
import SwiftData

struct LoginView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("Field Inspection")
                .font(.largeTitle.bold())
            Text("Sign in to Salesforce, select a plant, and complete today’s Work Task Step inspections.")
                .foregroundStyle(.secondary)
            if let authError = appEnvironment.authError {
                Text(authError)
                    .foregroundStyle(.red)
            }
            Button {
                Task { await appEnvironment.mockLogin() }
            } label: {
                if appEnvironment.isAuthenticating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Mock Salesforce Login", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appEnvironment.isAuthenticating)
            Spacer()
        }
        .padding()
    }
}

struct SiteSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @AppStorage("selectedSiteId") private var selectedSiteId = ""

    @State private var sites: [SiteEntity] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredSites: [SiteEntity] {
        guard searchText.isEmpty == false else { return sites }
        return sites.filter { site in
            site.name.localizedCaseInsensitiveContains(searchText) ||
            (site.uniqueName ?? "").localizedCaseInsensitiveContains(searchText) ||
            (site.stateProvince ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            SyncSummaryRow()

            if isLoading {
                ProgressView("Loading plants...")
            } else if let errorMessage {
                ContentUnavailableView("Could not load plants", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if filteredSites.isEmpty {
                ContentUnavailableView("No in-service plants", systemImage: "building.2")
            } else {
                ForEach(filteredSites) { site in
                    NavigationLink {
                        WorkOrdersTodayView(site: site.dto)
                            .onAppear {
                                selectedSiteId = site.id
                                appEnvironment.selectSite(site.dto)
                            }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.name).font(.headline)
                            Text([site.assetSubClass, site.stateProvince, site.uniqueName].compactMap { $0 }.joined(separator: " • "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Select Plant")
        .searchable(text: $searchText, prompt: "Search plants")
        .toolbar {
            Button { Task { await loadSites() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                .disabled(isLoading)
        }
        .task { await loadSites() }
    }

    private func loadSites() async {
        isLoading = true
        errorMessage = nil
        do {
            sites = try await SiteService(apiClient: appEnvironment.apiClient, repository: SiteRepository(modelContext: modelContext)).fetchSites()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct WorkOrdersTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment

    let site: SiteDTO

    @State private var workOrders: [WorkOrderEntity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name).font(.headline)
                    Text(Date.now, format: .dateTime.weekday(.wide).month().day().year())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Work Orders Scheduled Today") {
                if isLoading {
                    ProgressView("Loading work orders...")
                } else if let errorMessage {
                    ContentUnavailableView("Could not load work orders", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if workOrders.isEmpty {
                    ContentUnavailableView("No work orders today", systemImage: "calendar.badge.checkmark")
                } else {
                    ForEach(workOrders) { workOrder in
                        NavigationLink {
                            WorkOrderDetailView(workOrder: workOrder.dto, site: site)
                        } label: {
                            WorkOrderCard(workOrder: workOrder)
                        }
                    }
                }
            }
        }
        .navigationTitle("Today")
        .toolbar {
            Button { Task { await loadWorkOrders() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                .disabled(isLoading)
        }
        .refreshable { await loadWorkOrders() }
        .task { await loadWorkOrders() }
        .onAppear { appEnvironment.selectSite(site) }
    }

    private func loadWorkOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            workOrders = try await WorkOrderService(apiClient: appEnvironment.apiClient, repository: WorkOrderRepository(modelContext: modelContext)).fetchTodaysWorkOrders(siteId: site.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct WorkOrderCard: View {
    let workOrder: WorkOrderEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workOrder.name).font(.headline)
                Spacer()
                if let priority = workOrder.priority {
                    Text(priority)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }
            Text(workOrder.woType ?? "Work Order")
            Text([workOrder.woStatus, workOrder.siteAccess].compactMap { $0 }.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct WorkOrderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment

    let workOrder: WorkOrderDTO
    let site: SiteDTO

    @State private var taskCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoadInspection = false
    @State private var shouldOpenInspection = false

    var body: some View {
        List {
            Section("Work Order") {
                LabeledContent("Name", value: workOrder.name)
                LabeledContent("Status", value: workOrder.woStatus ?? workOrder.status ?? "-")
                LabeledContent("Type", value: workOrder.woType ?? "-")
                LabeledContent("Priority", value: workOrder.priority ?? "-")
                if let siteInstructions = workOrder.siteInstructions, siteInstructions.isEmpty == false {
                    Text(siteInstructions).foregroundStyle(.secondary)
                }
            }

            Section("Inspection") {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if let syncMessage = appEnvironment.syncMessage(for: workOrder.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(syncMessage.message)
                            .foregroundStyle(syncMessage.detail == nil ? .secondary : .primary)
                        if let detail = syncMessage.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if taskCount > 0 {
                    LabeledContent("Work Tasks", value: "\(taskCount)")
                }
                if didLoadInspection && taskCount == 0 {
                    Text("No work tasks were found for this work order.")
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await startInspection() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("Start Inspection", systemImage: "checklist")
                    }
                }
                .disabled(isLoading)
            }
        }
        .navigationTitle(workOrder.name)
        .navigationDestination(isPresented: $shouldOpenInspection) {
            InspectionFormView(workOrder: workOrder, site: site)
        }
        .task { loadLocalTaskCount() }
    }

    private func service() -> InspectionFormService {
        InspectionFormService(
            apiClient: appEnvironment.apiClient,
            taskRepository: WorkTaskRepository(modelContext: modelContext),
            stepRepository: WorkTaskStepRepository(modelContext: modelContext),
            draftRepository: LocalStepDraftRepository(modelContext: modelContext)
        )
    }

    private func loadLocalTaskCount() {
        do {
            taskCount = try WorkTaskRepository(modelContext: modelContext).forWorkOrder(workOrder.id).count
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startInspection() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service().loadInspection(workOrderId: workOrder.id)
            taskCount = result.tasks.count
            didLoadInspection = true
            shouldOpenInspection = result.tasks.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct InspectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appEnvironment: AppEnvironment

    let workOrder: WorkOrderDTO
    let site: SiteDTO

    @State private var tasks: [WorkTaskEntity] = []
    @State private var steps: [WorkTaskStepEntity] = []
    @State private var drafts: [LocalStepDraftEntity] = []
    @State private var validationErrors: Set<String> = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var bannerMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading inspection...")
            } else if let errorMessage {
                ContentUnavailableView("Could not load inspection", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if tasks.isEmpty {
                ContentUnavailableView("No work tasks", systemImage: "checklist", description: Text("This work order has no local work tasks. Return to the work order and start inspection again."))
            } else if steps.isEmpty {
                ContentUnavailableView("No task steps", systemImage: "list.bullet.rectangle", description: Text("No Work Task Steps were found for the downloaded tasks."))
            } else {
                ForEach(tasks) { task in
                    TaskSectionView(
                        task: task,
                        steps: stepsForTask(task),
                        drafts: drafts,
                        validationErrors: validationErrors,
                        onPhotoTapped: { step in queueStubPhoto(for: step) }
                    )
                }
            }
        }
        .navigationTitle("Inspection")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let bannerMessage {
                    Text(bannerMessage).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("Save Draft") { saveDraft() }
                        .buttonStyle(.bordered)
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSyncing {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Submit").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSyncing)
                }
            }
            .padding()
            .background(.bar)
        }
        .task { await loadLocalInspection() }
    }

    private func formService() -> InspectionFormService {
        InspectionFormService(apiClient: appEnvironment.apiClient, taskRepository: WorkTaskRepository(modelContext: modelContext), stepRepository: WorkTaskStepRepository(modelContext: modelContext), draftRepository: LocalStepDraftRepository(modelContext: modelContext))
    }

    private func stepsForTask(_ task: WorkTaskEntity) -> [WorkTaskStepEntity] {
        steps.filter { $0.workTaskId == task.id }
    }

    private func loadLocalInspection() async {
        isLoading = true
        errorMessage = nil
        do {
            let local = try formService().localInspection(workOrderId: workOrder.id)
            tasks = local.tasks
            steps = local.steps
            drafts = local.drafts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func saveDraft() {
        do {
            try modelContext.save()
            bannerMessage = "Draft saved locally."
        } catch {
            bannerMessage = error.localizedDescription
        }
    }

    private func submit() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try modelContext.save()
            validationErrors = Set(try formService().validationErrors(workOrderId: workOrder.id))
            guard validationErrors.isEmpty else {
                bannerMessage = "Select Pass or Fail for critical steps."
                return
            }
            let draftRepository = LocalStepDraftRepository(modelContext: modelContext)
            let syncService = InspectionSyncService(apiClient: appEnvironment.apiClient, draftRepository: draftRepository)
            try syncService.markWorkOrderPendingUpload(workOrder.id)
            dismiss()
            Task {
                await syncSubmittedInspection(workOrderId: workOrder.id)
            }
        } catch {
            bannerMessage = error.localizedDescription
            await loadLocalInspection()
        }
    }

    private func syncSubmittedInspection(workOrderId: String) async {
        let syncService = InspectionSyncService(
            apiClient: appEnvironment.apiClient,
            draftRepository: LocalStepDraftRepository(modelContext: modelContext)
        )
        do {
            _ = try await syncService.syncPendingStepUpdates()
            appEnvironment.recordWorkOrderSyncSuccess(workOrderId: workOrderId)
        } catch {
            appEnvironment.recordWorkOrderSyncFailure(
                workOrderId: workOrderId,
                error: error,
                isConnectivityError: InspectionSyncService.isConnectivityError(error)
            )
        }
    }

    private func queueStubPhoto(for step: WorkTaskStepEntity) {
        do {
            let draftRepository = LocalStepDraftRepository(modelContext: modelContext)
            if let draft = try draftRepository.draft(workOrderId: workOrder.id, stepId: step.id) {
                draft.localPhotoPath = "/tmp/\(step.id).jpg"
            }
            bannerMessage = "Photo capture is stubbed. Local path placeholder saved."
            try modelContext.save()
        } catch {
            bannerMessage = error.localizedDescription
        }
    }
}

struct TaskSectionView: View {
    let task: WorkTaskEntity
    let steps: [WorkTaskStepEntity]
    let drafts: [LocalStepDraftEntity]
    let validationErrors: Set<String>
    let onPhotoTapped: (WorkTaskStepEntity) -> Void

    var body: some View {
        Section {
            ForEach(steps) { step in
                if let draft = drafts.first(where: { $0.workTaskStepId == step.id }) {
                    StepResponseView(step: step, draft: draft, hasValidationError: validationErrors.contains(step.id), onPhotoTapped: onPhotoTapped)
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                if let description = task.descriptionText, description.isEmpty == false {
                    Text(description).font(.caption).textCase(nil)
                }
            }
        }
    }
}

struct StepResponseView: View {
    let step: WorkTaskStepEntity
    @Bindable var draft: LocalStepDraftEntity
    let hasValidationError: Bool
    let onPhotoTapped: (WorkTaskStepEntity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.name).font(.headline)
                    Text(step.additionalDetails ?? step.recommendedAction ?? "No additional details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if step.criticalInspection {
                    Text("Critical")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            Picker("Result", selection: Binding(
                get: { draft.result },
                set: { draft.result = $0 }
            )) {
                ForEach(StepResult.allCases) { result in
                    Text(result.title).tag(result)
                }
            }
            .pickerStyle(.segmented)

            TextField("Comments", text: $draft.comments, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Button { onPhotoTapped(step) } label: {
                Label(draft.localPhotoPath == nil ? "Add Photo Placeholder" : "Photo Placeholder Saved", systemImage: "camera")
            }
            .buttonStyle(.bordered)

            if draft.syncStatus != .draft {
                Text("Sync: \(draft.syncStatus.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let lastSyncError = draft.lastSyncError {
                Text(lastSyncError).font(.caption).foregroundStyle(.red)
            }
            if hasValidationError {
                Text("Critical step requires Pass or Fail.").font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SyncSummaryRow: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @State private var pendingUploadCount = 0
    @State private var failedSyncCount = 0
    @State private var localError: String?

    var body: some View {
        Section {
            NavigationLink {
                SyncStatusDetailView()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                        Spacer()
                        if pendingUploadCount == 0 && failedSyncCount == 0 {
                            Text("Up to date")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 16) {
                        Text("Pending: \(pendingUploadCount)")
                        Text("Failed: \(failedSyncCount)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let lastSuccessfulSync = appEnvironment.lastSuccessfulSync {
                        Text("Last sync: \(lastSuccessfulSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = appEnvironment.lastSyncError ?? localError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .task { refreshCounts() }
        .onAppear { refreshCounts() }
    }

    private func refreshCounts() {
        do {
            let service = InspectionSyncService(apiClient: appEnvironment.apiClient, draftRepository: LocalStepDraftRepository(modelContext: modelContext))
            pendingUploadCount = try service.pendingUploadCount()
            failedSyncCount = try service.syncErrorCount()
        } catch {
            localError = error.localizedDescription
        }
    }
}

struct SyncStatusDetailView: View {
    var body: some View {
        List {
            SyncStatusView()
        }
        .navigationTitle("Sync Status")
    }
}

struct SyncStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @State private var pendingCount = 0
    @State private var pendingUploadCount = 0
    @State private var syncErrorCount = 0
    @State private var isSyncing = false
    @State private var localError: String?

    var body: some View {
        Section("Sync") {
            #if DEBUG
            LabeledContent("Backend", value: appEnvironment.backendTypeName)
            #endif
            LabeledContent("Pending Uploads", value: "\(pendingUploadCount)")
            LabeledContent("Failed Syncs", value: "\(syncErrorCount)")
            if let lastSuccessfulSync = appEnvironment.lastSuccessfulSync {
                LabeledContent("Last Success", value: lastSuccessfulSync.formatted(date: .abbreviated, time: .shortened))
            }
            if let error = appEnvironment.lastSyncError ?? localError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Button {
                Task { await retrySync() }
            } label: {
                if isSyncing {
                    ProgressView()
                } else {
                    Label("Retry Sync", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(isSyncing || pendingCount == 0)
        }
        .task { refreshPendingCount() }
    }

    private func refreshPendingCount() {
        do {
            let service = InspectionSyncService(apiClient: appEnvironment.apiClient, draftRepository: LocalStepDraftRepository(modelContext: modelContext))
            pendingCount = try service.pendingCount()
            pendingUploadCount = try service.pendingUploadCount()
            syncErrorCount = try service.syncErrorCount()
        } catch {
            localError = error.localizedDescription
        }
    }

    private func retrySync() async {
        isSyncing = true
        localError = nil
        do {
            _ = try await InspectionSyncService(apiClient: appEnvironment.apiClient, draftRepository: LocalStepDraftRepository(modelContext: modelContext)).syncPendingStepUpdates()
            appEnvironment.recordSyncSuccess()
        } catch {
            localError = error.localizedDescription
            appEnvironment.recordSyncFailure(error.localizedDescription)
        }
        refreshPendingCount()
        isSyncing = false
    }
}
