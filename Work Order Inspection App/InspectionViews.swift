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
            #if DEBUG
            Picker("Backend", selection: Binding(
                get: { appEnvironment.selectedBackend },
                set: { appEnvironment.selectBackend($0) }
            )) {
                ForEach(AppBackendSelection.allCases) { backend in
                    Text(backend.rawValue).tag(backend)
                }
            }
            .pickerStyle(.segmented)
            Text("Current backend: \(appEnvironment.selectedBackend.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if appEnvironment.selectedBackend == .realManual {
                ManualSalesforceSessionFields()
            }
            #endif
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
                    Label(appEnvironment.isUsingMockClient ? "Mock Salesforce Login" : "Log In with Salesforce", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appEnvironment.isAuthenticating)
            #if DEBUG
            NavigationLink {
                SalesforceDeveloperTestView()
            } label: {
                Label("Developer Salesforce Test", systemImage: "wrench.and.screwdriver")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            #endif
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
            site.displayName.localizedCaseInsensitiveContains(searchText) ||
            site.pfIdPrefix.localizedCaseInsensitiveContains(searchText) ||
            (site.uniqueName ?? "").localizedCaseInsensitiveContains(searchText) ||
            (site.stateProvince ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            #if DEBUG
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current backend: \(appEnvironment.selectedBackend.rawValue)")
                        .font(.headline)
                    Picker("Backend", selection: Binding(
                        get: { appEnvironment.selectedBackend },
                        set: { appEnvironment.selectBackend($0) }
                    )) {
                        ForEach(AppBackendSelection.allCases) { backend in
                            Text(backend.rawValue).tag(backend)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if appEnvironment.selectedBackend == .realManual {
                    ManualSalesforceSessionFields()
                }
                if appEnvironment.selectedBackend != .mock && appEnvironment.isAuthenticated == false {
                    Text("Salesforce login required.")
                        .foregroundStyle(.secondary)
                    Button(appEnvironment.selectedBackend == .realManual ? "Use Manual Session" : "Log In with Salesforce") {
                        Task { await appEnvironment.mockLogin() }
                    }
                    .disabled(appEnvironment.isAuthenticating)
                }
            }
            #endif
            SyncSummaryRow()
            #if DEBUG
            Section {
                NavigationLink {
                    SalesforceDeveloperTestView()
                } label: {
                    Label("Developer Salesforce Test", systemImage: "wrench.and.screwdriver")
                }
            }
            #endif

            if isLoading {
                ProgressView("Loading plants...")
            } else if let errorMessage {
                ContentUnavailableView("Could not load plants", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if filteredSites.isEmpty {
                ContentUnavailableView("No plants found", systemImage: "building.2", description: Text("No in-service plant records are available for this Salesforce session."))
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
                            Text(site.displayName).font(.headline)
                            Text(site.pfIdPrefix)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            let details = [site.assetSubClass, site.stateProvince, site.uniqueName].compactMap { $0 }.joined(separator: " • ")
                            if details.isEmpty == false {
                                Text(details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
            Button("Logout") {
                Task { await appEnvironment.logout() }
            }
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

#if DEBUG
private struct ManualSalesforceSessionFields: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Salesforce Instance URL", text: Binding(
                get: { appEnvironment.manualInstanceURLText },
                set: { appEnvironment.updateManualSession(instanceURLText: $0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)

            SecureField("Salesforce Access Token", text: Binding(
                get: { appEnvironment.manualAccessToken },
                set: { appEnvironment.updateManualSession(accessToken: $0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button("Clear Manual Session") {
                appEnvironment.clearManualSession()
            }
            .buttonStyle(.bordered)

            Text("DEBUG only. The token is kept in memory and is not written to SwiftData or source code.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif

struct WorkOrdersTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment

    let site: SiteDTO

    @State private var workOrders: [WorkOrderEntity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    #if DEBUG
    @State private var workOrderDiagnostics: String?
    #endif

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.displayName).font(.headline)
                    Text(site.pfIdPrefix)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Date.now, format: .dateTime.weekday(.wide).month().day().year())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            #if DEBUG
            Section("Read Diagnostics") {
                LabeledContent("Backend", value: appEnvironment.selectedBackend.rawValue)
                LabeledContent("Site Name", value: site.name)
                LabeledContent("Friendly Name", value: site.displayName)
                LabeledContent("PF Prefix", value: site.pfIdPrefix)
                LabeledContent("Work Orders", value: "\(workOrders.count)")
            }
            #endif

            Section("Work Orders Scheduled Today") {
                if isLoading {
                    ProgressView("Loading work orders...")
                } else if let errorMessage {
                    ContentUnavailableView("Could not load work orders", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if workOrders.isEmpty {
                    ContentUnavailableView("No work orders scheduled for this site today.", systemImage: "calendar.badge.checkmark")
                    #if DEBUG
                    if let workOrderDiagnostics {
                        Text(workOrderDiagnostics)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    #endif
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
        #if DEBUG
        workOrderDiagnostics = nil
        #endif
        do {
            let service = WorkOrderService(apiClient: appEnvironment.apiClient, repository: WorkOrderRepository(modelContext: modelContext))
            #if DEBUG
            let result = try await service.fetchTodaysWorkOrdersWithDiagnostics(site: site)
            workOrders = result.workOrders
            workOrderDiagnostics = result.diagnostics
            #else
            workOrders = try await service.fetchTodaysWorkOrders(site: site)
            #endif
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
            if let description = workOrder.descriptionText, description.isEmpty == false {
                SalesforceRichTextDisplay(description)
                    .font(.subheadline)
            }
            if let assetDescription = workOrder.assetDescription, assetDescription.isEmpty == false {
                SalesforceRichTextDisplay(assetDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
    @State private var stepCount = 0
    @State private var isRetryingSync = false

    var body: some View {
        List {
            Section("Work Order") {
                LabeledContent("Name", value: workOrder.name)
                LabeledContent("Status", value: workOrder.woStatus ?? workOrder.status ?? "-")
                LabeledContent("Type", value: workOrder.woType ?? "-")
                LabeledContent("Priority", value: workOrder.priority ?? "-")
                if let description = workOrder.descriptionText, description.isEmpty == false {
                    SalesforceRichTextDisplay(description).foregroundStyle(.secondary)
                }
                if let assetDescription = workOrder.assetDescription, assetDescription.isEmpty == false {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Equipment").font(.caption).foregroundStyle(.secondary)
                        SalesforceRichTextDisplay(assetDescription)
                    }
                }
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
                Button {
                    Task { await retrySync() }
                } label: {
                    if isRetryingSync {
                        ProgressView()
                    } else {
                        Label("Retry Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isRetryingSync)
                if taskCount > 0 {
                    LabeledContent("Work Tasks", value: "\(taskCount)")
                }
                #if DEBUG
                LabeledContent("Backend", value: appEnvironment.selectedBackend.rawValue)
                LabeledContent("Site", value: site.displayName)
                LabeledContent("Site Name", value: site.name)
                LabeledContent("PF Prefix", value: site.pfIdPrefix)
                LabeledContent("Task Count", value: "\(taskCount)")
                LabeledContent("Step Count", value: "\(stepCount)")
                #endif
                if didLoadInspection && taskCount == 0 {
                    Text("No work tasks found for this work order.")
                        .foregroundStyle(.secondary)
                }
                if didLoadInspection && taskCount > 0 && stepCount == 0 {
                    Text("No work task steps found for this work order.")
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
            stepCount = result.steps.count
            didLoadInspection = true
            shouldOpenInspection = result.tasks.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func retrySync() async {
        isRetryingSync = true
        errorMessage = nil
        let syncService = InspectionSyncService(
            apiClient: appEnvironment.apiClient,
            draftRepository: LocalStepDraftRepository(modelContext: modelContext)
        )
        do {
            _ = try await syncService.syncPendingStepUpdates()
            appEnvironment.recordWorkOrderSyncSuccess(workOrderId: workOrder.id)
        } catch {
            appEnvironment.recordWorkOrderSyncFailure(
                workOrderId: workOrder.id,
                error: error,
                isConnectivityError: InspectionSyncService.isConnectivityError(error)
            )
        }
        isRetryingSync = false
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
    #if DEBUG
    @State private var showRealWritebackConfirmation = false
    @State private var hasConfirmedRealWriteback = false
    #endif

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading inspection...")
            } else if let errorMessage {
                ContentUnavailableView("Could not load inspection", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if tasks.isEmpty {
                ContentUnavailableView("No work tasks", systemImage: "checklist", description: Text("No work tasks were found for this work order."))
            } else if steps.isEmpty {
                ContentUnavailableView("No work task steps", systemImage: "list.bullet.rectangle", description: Text("No Work Task Steps were found for this work order."))
            } else {
                #if DEBUG
                Section("Read Diagnostics") {
                    LabeledContent("Backend", value: appEnvironment.selectedBackend.rawValue)
                    LabeledContent("Work Tasks", value: "\(tasks.count)")
                    LabeledContent("Work Task Steps", value: "\(steps.count)")
                }
                #endif
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
                        #if DEBUG
                        if appEnvironment.apiClient is RealSalesforceAPIClient && hasConfirmedRealWriteback == false {
                            showRealWritebackConfirmation = true
                        } else {
                            Task { await submit() }
                        }
                        #else
                        Task { await submit() }
                        #endif
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
        #if DEBUG
        .alert("This will update Salesforce Work Task Steps. Continue?", isPresented: $showRealWritebackConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                hasConfirmedRealWriteback = true
                Task { await submit() }
            }
        } message: {
            Text("Only pffsm__Work_Task_Step__c records will be updated.")
        }
        #endif
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
            // Submit is local-first: mark changed drafts pending, close the form, then upload in the background.
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
                if SalesforceRichTextFormatter.displayText(from: task.descriptionText).isEmpty == false {
                    SalesforceRichTextDisplay(task.descriptionText)
                        .font(.caption)
                        .textCase(nil)
                }
                if SalesforceRichTextFormatter.displayText(from: task.instructionsRT).isEmpty == false {
                    SalesforceRichTextDisplay(task.instructionsRT)
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
    }
}

private struct SalesforceRichTextDisplay: View {
    private let rawText: String?
    private let fallback: String

    init(_ rawText: String?, fallback: String = "") {
        self.rawText = rawText
        self.fallback = fallback
    }

    var body: some View {
        let displayText = SalesforceRichTextFormatter.displayText(from: rawText)
        let finalText = displayText.isEmpty ? fallback : displayText
        Text(finalText)
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
                    SalesforceRichTextDisplay(step.additionalDetails ?? step.recommendedAction, fallback: "No additional details.")
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

#if DEBUG
private enum DeveloperSalesforceBackend: String, CaseIterable, Identifiable {
    case mock = "Mock Salesforce"
    case manual = "Real Salesforce Manual Session"
    case oauth = "Real Salesforce OAuth"

    var id: String { rawValue }
}

struct SalesforceDeveloperTestView: View {
    @State private var backend: DeveloperSalesforceBackend = .mock
    @State private var instanceURLText = "https://pfdrive-origis.my.salesforce.com"
    @State private var accessToken = ""
    @State private var selectedSiteId = ""
    @State private var selectedWorkOrderId = ""
    @State private var sites: [SiteDTO] = []
    @State private var workOrders: [WorkOrderDTO] = []
    @State private var tasks: [WorkTaskDTO] = []
    @State private var steps: [WorkTaskStepDTO] = []
    @State private var resultMessage = "No test has run yet."
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Backend") {
                Picker("Backend", selection: $backend) {
                    ForEach(DeveloperSalesforceBackend.allCases) { backend in
                        Text(backend.rawValue).tag(backend)
                    }
                }

                if backend == .manual {
                    TextField("Salesforce Instance URL", text: $instanceURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Salesforce Access Token", text: $accessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("DEBUG only. Token is kept in memory for this screen and is not written to SwiftData or source control.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Site Query") {
                Button("Test Site Query") {
                    Task { await testSites() }
                }
                .disabled(isTesting)

                if sites.isEmpty == false {
                    Picker("Returned Site", selection: $selectedSiteId) {
                        Text("Select").tag("")
                        ForEach(sites) { site in
                            Text("\(site.displayName) - \(site.pfIdPrefix)").tag(site.id)
                        }
                    }
                }
            }

            Section("Work Orders") {
                if let selectedSite = selectedSiteForPrefix {
                    let prefix = SitePFIDPrefix.derive(from: selectedSite.name)
                    LabeledContent("Selected Site", value: selectedSite.displayName)
                    LabeledContent("Equipment Name", value: selectedSite.name)
                    LabeledContent("PF ID Prefix", value: prefix.value)
                    if prefix.isReliable == false {
                        Text("Prefix fallback is less reliable for this site name.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Test Work Orders by Equipment Name Prefix") {
                    Task { await testWorkOrdersByEquipmentNamePrefix(last30Days: false) }
                }
                .disabled(isTesting || selectedSiteForPrefix == nil)

                Button("Test Work Orders by Equipment Name Prefix - Last 30 Days") {
                    Task { await testWorkOrdersByEquipmentNamePrefix(last30Days: true) }
                }
                .disabled(isTesting || selectedSiteForPrefix == nil)

                if workOrders.isEmpty == false {
                    Picker("Returned Work Order", selection: $selectedWorkOrderId) {
                        Text("Select").tag("")
                        ForEach(workOrders) { workOrder in
                            Text(workOrder.name).tag(workOrder.id)
                        }
                    }
                }
            }

            Section("Tasks and Steps") {
                Button("Test Work Tasks Query") {
                    Task { await testTasks() }
                }
                .disabled(isTesting || selectedWorkOrderId.isEmpty)

                Button("Test Work Task Steps Query") {
                    Task { await testSteps() }
                }
                .disabled(isTesting || tasks.isEmpty)
            }

            Section("Manual Session") {
                Button("Clear Manual Session") {
                    instanceURLText = "https://pfdrive-origis.my.salesforce.com"
                    accessToken = ""
                    sites = []
                    workOrders = []
                    tasks = []
                    steps = []
                    selectedSiteId = ""
                    selectedWorkOrderId = ""
                    resultMessage = "Manual session cleared."
                }
                .disabled(isTesting)
            }

            Section("Result") {
                if isTesting {
                    ProgressView("Running test...")
                }
                Text(resultMessage)
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Salesforce Test")
    }

    private var selectedSiteForPrefix: SiteDTO? {
        sites.first { $0.id == selectedSiteId }
    }

    private func makeClient() async throws -> SalesforceAPIClient {
        switch backend {
        case .mock:
            return MockSalesforceAPIClient()
        case .manual:
            guard let instanceURL = URL(string: instanceURLText.trimmingCharacters(in: .whitespacesAndNewlines)), accessToken.isEmpty == false else {
                throw SalesforceAPIError.sessionNotConfigured
            }
            let session = SalesforceSession(accessToken: accessToken, refreshToken: nil, instanceURL: instanceURL, issuedAt: Date(), expiresAt: nil)
            return RealSalesforceAPIClient(config: .current, session: session, tokenStore: EphemeralSalesforceTokenStore())
        case .oauth:
            let client = RealSalesforceAPIClient(config: .current)
            _ = try await client.authenticate()
            return client
        }
    }

    private func testSites() async {
        await runTest {
            let client = try await makeClient()
            sites = try await client.fetchSites()
            selectedSiteId = sites.first?.id ?? ""
            let names = sites.prefix(5).map { "\($0.displayName) - \($0.pfIdPrefix)" }.joined(separator: "\n")
            return """
            Connected to Salesforce.
            Plant sites returned: \(sites.count)
            \(names)
            """
        }
    }

    private func testWorkOrdersByEquipmentNamePrefix(last30Days: Bool) async {
        await runTest {
            guard let selectedSite = selectedSiteForPrefix else {
                return "Select a returned plant site before testing equipment name prefix lookup."
            }
            let prefix = SitePFIDPrefix.derive(from: selectedSite.name)
            let client = try await makeClient()
            guard let realClient = client as? RealSalesforceAPIClient else {
                workOrders = try await client.fetchWorkOrders(siteId: selectedSite.id, scheduledDate: Date())
                selectedWorkOrderId = workOrders.first?.id ?? ""
                return "Mock backend does not have child equipment name relationships. Returned mock Work Orders: \(workOrders.count)\n\(workOrderSummaryLines(workOrders))"
            }

            workOrders = last30Days
                ? try await realClient.fetchWorkOrdersForLast30Days(equipmentNamePrefix: prefix.value)
                : try await realClient.fetchWorkOrders(equipmentNamePrefix: prefix.value)
            selectedWorkOrderId = workOrders.first?.id ?? ""
            if workOrders.isEmpty {
                if last30Days {
                    return """
                    Selected site: \(selectedSite.displayName)
                    Equipment name: \(selectedSite.name)
                    Derived PF ID prefix: \(prefix.value)
                    Work orders returned: 0
                    No work orders found for this site prefix in the last 30 days. Confirm the equipment relationship name and scheduled date field if this is unexpected.
                    """
                }
                return """
                Selected site: \(selectedSite.displayName)
                Equipment name: \(selectedSite.name)
                Derived PF ID prefix: \(prefix.value)
                Work orders returned: 0
                No work orders found for this site prefix today. This may mean none are scheduled today, or the scheduled start date filter needs a wider test range.
                """
            }
            return """
            Selected site: \(selectedSite.displayName)
            Equipment name: \(selectedSite.name)
            Derived PF ID prefix: \(prefix.value)
            Work orders returned: \(workOrders.count)
            \(workOrderSummaryLines(workOrders))
            """
        }
    }

    private func workOrderSummaryLines(_ workOrders: [WorkOrderDTO]) -> String {
        workOrders.prefix(10).map { workOrder in
            let status = [workOrder.status, workOrder.woStatus].compactMap { $0 }.joined(separator: " / ")
            let date = workOrder.scheduledStartDate == Date.distantPast ? nil : workOrder.scheduledStartDate.formatted(date: .abbreviated, time: .omitted)
            return [workOrder.name, workOrder.assetName, workOrder.accountSR, status.isEmpty ? nil : status, date].compactMap { $0 }.joined(separator: " - ")
        }.joined(separator: "\n")
    }

    private func testTasks() async {
        await runTest {
            let client = try await makeClient()
            tasks = try await client.fetchWorkTasks(workOrderId: selectedWorkOrderId)
            let lines = tasks.prefix(10).map(\.name).joined(separator: "\n")
            return """
            Work Order Id: \(selectedWorkOrderId)
            Tasks returned: \(tasks.count)
            \(lines)
            """
        }
    }

    private func testSteps() async {
        await runTest {
            guard tasks.isEmpty == false else {
                return "No work tasks found for this work order."
            }
            let client = try await makeClient()
            steps = try await client.fetchWorkTaskSteps(workTaskIds: tasks.map(\.id))
            let selectedWorkOrderName = workOrders.first { $0.id == selectedWorkOrderId }?.name ?? selectedWorkOrderId
            let groupedSteps = Dictionary(grouping: steps, by: \.workTaskId)
            let taskLines = tasks.map { task in
                let taskSteps = groupedSteps[task.id] ?? []
                let stepNames = taskSteps.prefix(3).map(\.name).joined(separator: ", ")
                let sampleText = stepNames.isEmpty ? "No steps returned" : stepNames
                return "\(task.name): \(taskSteps.count) steps - \(sampleText)"
            }.joined(separator: "\n")
            return """
            Work Order: \(selectedWorkOrderName)
            Total Work Tasks returned: \(tasks.count)
            Total Work Task Steps returned: \(steps.count)
            \(taskLines)
            """
        }
    }

    private func runTest(_ operation: @escaping () async throws -> String) async {
        isTesting = true
        defer { isTesting = false }
        do {
            resultMessage = try await operation()
        } catch {
            resultMessage = formattedError(error)
        }
    }

    private func formattedError(_ error: Error) -> String {
        var message = error.localizedDescription
        if case let SalesforceAPIError.requestFailed(statusCode, body) = error {
            message = "Salesforce request failed with HTTP \(statusCode)."
            if let fieldName = invalidFieldName(in: body) {
                message += "\nInvalid field: \(fieldName)"
            }
            if body.localizedCaseInsensitiveContains("pffsm__Equipment__r") || body.localizedCaseInsensitiveContains("relationship") {
                message += "\nConfirm the actual relationship name for pffsm__Equipment__c from Salesforce describe metadata."
            }
            if body.isEmpty == false {
                message += "\n\(body)"
            }
        }
        if case let SalesforceAPIError.decodingFailed(detail) = error {
            message = "Could not decode Salesforce response.\n\(detail)"
        }
        return message
    }

    private func invalidFieldName(in body: String) -> String? {
        guard let range = body.range(of: "No such column '") else {
            return nil
        }
        let remainder = body[range.upperBound...]
        guard let end = remainder.firstIndex(of: "'") else {
            return nil
        }
        return String(remainder[..<end])
    }
}
#endif
