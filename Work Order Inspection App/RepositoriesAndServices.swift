import Foundation
import SwiftData

@MainActor
protocol ModelSaving {
    var modelContext: ModelContext { get }
}

@MainActor
extension ModelSaving {
    func saveIfNeeded() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}

@MainActor
struct SiteRepository: ModelSaving {
    let modelContext: ModelContext

    func upsert(_ sites: [SiteDTO]) throws {
        for site in sites {
            if let existing = try find(id: site.id) {
                existing.update(from: site)
            } else {
                modelContext.insert(SiteEntity(dto: site))
            }
        }
        try saveIfNeeded()
    }

    func allPlantsInService(applySiteNameFilter: Bool = true) throws -> [SiteEntity] {
        try modelContext.fetch(FetchDescriptor<SiteEntity>(sortBy: [SortDescriptor(\SiteEntity.name)]))
            .filter { site in
                site.assetClass == "Plant" &&
                site.status == "In Service" &&
                (applySiteNameFilter == false || SiteRepository.isLikelyPlantSiteName(site.name))
            }
    }

    func find(id: String) throws -> SiteEntity? {
        try modelContext.fetch(FetchDescriptor<SiteEntity>()).first { $0.id == id }
    }

    static func isLikelyPlantSiteName(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        guard lowercasedName.contains(".plant") else { return false }
        let childEquipmentTerms = ["inverter", "inv", "pcs", "tracker", "combiner", "transformer", "met", "weather", "skid", "block", "string", "feeder", "breaker"]
        return childEquipmentTerms.contains { lowercasedName.contains($0.lowercased()) } == false
    }
}

@MainActor
struct WorkOrderRepository: ModelSaving {
    let modelContext: ModelContext

    func upsert(_ workOrders: [WorkOrderDTO]) throws {
        for workOrder in workOrders {
            if let existing = try find(id: workOrder.id) {
                existing.update(from: workOrder)
            } else {
                modelContext.insert(WorkOrderEntity(dto: workOrder))
            }
        }
        try saveIfNeeded()
    }

    func forSite(_ siteId: String, scheduledDate: Date) throws -> [WorkOrderEntity] {
        let start = Calendar.current.startOfDay(for: scheduledDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? scheduledDate
        return try modelContext.fetch(FetchDescriptor<WorkOrderEntity>(sortBy: [SortDescriptor(\WorkOrderEntity.name)]))
            .filter { $0.assetId == siteId && $0.scheduledStartDate >= start && $0.scheduledStartDate < end }
    }

    func forSite(_ siteId: String, equipmentNamePrefix: String, scheduledDate: Date) throws -> [WorkOrderEntity] {
        let start = Calendar.current.startOfDay(for: scheduledDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? scheduledDate
        return try modelContext.fetch(FetchDescriptor<WorkOrderEntity>(sortBy: [SortDescriptor(\WorkOrderEntity.name)]))
            .filter { workOrder in
                let matchesSelectedSite = workOrder.assetId == siteId
                let matchesChildEquipment = workOrder.assetName?.hasPrefix(equipmentNamePrefix) == true
                return (matchesSelectedSite || matchesChildEquipment) && workOrder.scheduledStartDate >= start && workOrder.scheduledStartDate < end
            }
    }

    func find(id: String) throws -> WorkOrderEntity? {
        try modelContext.fetch(FetchDescriptor<WorkOrderEntity>()).first { $0.id == id }
    }

    func forIds(_ ids: [String]) throws -> [WorkOrderEntity] {
        try modelContext.fetch(FetchDescriptor<WorkOrderEntity>(sortBy: [SortDescriptor(\WorkOrderEntity.name)]))
            .filter { ids.contains($0.id) }
    }
}

@MainActor
struct WorkTaskRepository: ModelSaving {
    let modelContext: ModelContext

    func upsert(_ tasks: [WorkTaskDTO]) throws {
        for task in tasks {
            if let existing = try find(id: task.id) {
                existing.update(from: task)
            } else {
                modelContext.insert(WorkTaskEntity(dto: task))
            }
        }
        try saveIfNeeded()
    }

    func forWorkOrder(_ workOrderId: String) throws -> [WorkTaskEntity] {
        try modelContext.fetch(FetchDescriptor<WorkTaskEntity>())
            .filter { $0.workOrderId == workOrderId }
            .sorted { lhs, rhs in
                if lhs.step == rhs.step { return lhs.name < rhs.name }
                return (lhs.step ?? 0) < (rhs.step ?? 0)
            }
    }

    func find(id: String) throws -> WorkTaskEntity? {
        try modelContext.fetch(FetchDescriptor<WorkTaskEntity>()).first { $0.id == id }
    }
}

@MainActor
struct WorkTaskStepRepository: ModelSaving {
    let modelContext: ModelContext

    func upsert(_ steps: [WorkTaskStepDTO]) throws {
        for step in steps {
            if let existing = try find(id: step.id) {
                existing.update(from: step)
            } else {
                modelContext.insert(WorkTaskStepEntity(dto: step))
            }
        }
        try saveIfNeeded()
    }

    func forTasks(_ taskIds: [String]) throws -> [WorkTaskStepEntity] {
        try modelContext.fetch(FetchDescriptor<WorkTaskStepEntity>())
            .filter { taskIds.contains($0.workTaskId) }
            .sorted { lhs, rhs in
                if lhs.workTaskId == rhs.workTaskId {
                    if lhs.sequence == rhs.sequence { return lhs.name < rhs.name }
                    return (lhs.sequence ?? 0) < (rhs.sequence ?? 0)
                }
                return lhs.workTaskId < rhs.workTaskId
            }
    }

    func find(id: String) throws -> WorkTaskStepEntity? {
        try modelContext.fetch(FetchDescriptor<WorkTaskStepEntity>()).first { $0.id == id }
    }
}

@MainActor
struct LocalStepDraftRepository: ModelSaving {
    let modelContext: ModelContext

    func draft(workOrderId: String, stepId: String) throws -> LocalStepDraftEntity? {
        let draftKey = LocalStepDraftEntity.makeDraftKey(workOrderId: workOrderId, stepId: stepId)
        let existing = try modelContext.fetch(FetchDescriptor<LocalStepDraftEntity>()).first {
            $0.draftKey == draftKey || ($0.workOrderId == workOrderId && $0.workTaskStepId == stepId)
        }
        if existing?.draftKey == nil {
            existing?.draftKey = draftKey
            try saveIfNeeded()
        }
        return existing
    }

    func drafts(workOrderId: String) throws -> [LocalStepDraftEntity] {
        try modelContext.fetch(FetchDescriptor<LocalStepDraftEntity>()).filter { $0.workOrderId == workOrderId }
    }

    func pendingDrafts() throws -> [LocalStepDraftEntity] {
        try modelContext.fetch(FetchDescriptor<LocalStepDraftEntity>()).filter { draft in
            draft.syncStatus == .pendingUpload || draft.syncStatus == .syncError
        }
    }

    func pendingUploadCount() throws -> Int {
        try modelContext.fetch(FetchDescriptor<LocalStepDraftEntity>()).filter { $0.syncStatus == .pendingUpload }.count
    }

    func syncErrorCount() throws -> Int {
        try modelContext.fetch(FetchDescriptor<LocalStepDraftEntity>()).filter { $0.syncStatus == .syncError }.count
    }

    func buildDrafts(workOrderId: String, tasks: [WorkTaskEntity], steps: [WorkTaskStepEntity]) throws {
        for step in steps {
            if let existing = try draft(workOrderId: workOrderId, stepId: step.id) {
                existing.originalResultRawValue = existing.originalResultRawValue ?? existing.resultRawValue
                existing.originalComments = existing.originalComments ?? existing.comments
                continue
            }
            modelContext.insert(LocalStepDraftEntity(
                workOrderId: workOrderId,
                workTaskId: step.workTaskId,
                workTaskStepId: step.id,
                result: StepResult(salesforceValue: step.userPicklist),
                comments: step.comments ?? "",
                completedAt: step.trackCompleteTime,
                syncStatus: .draft
            ))
        }
        _ = tasks
        try saveIfNeeded()
    }

    func markWorkOrderPendingUpload(_ workOrderId: String) throws {
        for draft in try drafts(workOrderId: workOrderId) {
            guard draft.hasChangesForUpload || draft.syncStatus == .syncError else { continue }
            draft.syncStatus = .pendingUpload
            draft.completedAt = draft.completedAt ?? Date()
            draft.lastSyncError = nil
        }
        try saveIfNeeded()
    }

    func pendingCount() throws -> Int {
        try pendingDrafts().count
    }
}

@MainActor
struct PendingPhotoUploadRepository: ModelSaving {
    let modelContext: ModelContext

    func addPhoto(stepId: String, fileName: String, mimeType: String, localPath: String) throws {
        modelContext.insert(PendingPhotoUploadEntity(stepId: stepId, fileName: fileName, mimeType: mimeType, localPath: localPath, syncStatus: .pendingUpload))
        try saveIfNeeded()
    }

    func pendingUploads() throws -> [PendingPhotoUploadEntity] {
        try modelContext.fetch(FetchDescriptor<PendingPhotoUploadEntity>()).filter { photo in
            photo.syncStatus == .pendingUpload || photo.syncStatus == .syncError
        }
    }
}

@MainActor
struct SiteService {
    let apiClient: SalesforceAPIClient
    let repository: SiteRepository

    func fetchSites() async throws -> [SiteEntity] {
        let sites = try await apiClient.fetchSites()
        try repository.upsert(sites)
        return try repository.allPlantsInService(applySiteNameFilter: (apiClient is MockSalesforceAPIClient) == false)
    }
}

@MainActor
struct WorkOrderService {
    let apiClient: SalesforceAPIClient
    let repository: WorkOrderRepository

    func fetchTodaysWorkOrders(site: SiteDTO) async throws -> [WorkOrderEntity] {
        let today = Date()
        let workOrders = try await apiClient.fetchWorkOrders(site: site, scheduledDate: today)
        try repository.upsert(workOrders)
        if apiClient is RealSalesforceAPIClient {
            return try repository.forIds(workOrders.map(\.id))
        }
        return try repository.forSite(site.id, equipmentNamePrefix: site.pfIdPrefix, scheduledDate: today)
    }

    #if DEBUG
    func fetchTodaysWorkOrdersWithDiagnostics(site: SiteDTO) async throws -> (workOrders: [WorkOrderEntity], diagnostics: String?) {
        let today = Date()
        let prefix = site.pfIdPrefix
        let todayQuery = SalesforceSchema.workOrdersForEquipmentNamePrefixQuery(prefix: prefix)
        let workOrders = try await apiClient.fetchWorkOrders(site: site, scheduledDate: today)
        try repository.upsert(workOrders)
        let displayedWorkOrders: [WorkOrderEntity]
        if apiClient is RealSalesforceAPIClient {
            displayedWorkOrders = try repository.forIds(workOrders.map(\.id))
        } else {
            displayedWorkOrders = try repository.forSite(site.id, equipmentNamePrefix: prefix, scheduledDate: today)
        }

        guard let realClient = apiClient as? RealSalesforceAPIClient else {
            return (displayedWorkOrders, nil)
        }

        var diagnostics = """
        Selected site friendlyName: \(site.displayName)
        Selected site Salesforce Id: \(site.id)
        Selected site raw Name: \(site.name)
        Derived PF ID prefix: \(prefix)
        Scheduled date: \(today.formatted(date: .abbreviated, time: .shortened))
        Today SOQL:
        \(todayQuery)
        Today Work Orders returned: \(workOrders.count)
        Work Orders displayed: \(displayedWorkOrders.count)
        """

        if workOrders.isEmpty {
            let last30Query = SalesforceSchema.workOrdersForEquipmentNamePrefixLast30DaysQuery(prefix: prefix)
            let last30WorkOrders = try await realClient.fetchWorkOrdersForLast30Days(equipmentNamePrefix: prefix)
            diagnostics += """

            Last 30 Days SOQL:
            \(last30Query)
            Last 30 Days Work Orders returned: \(last30WorkOrders.count)
            \(last30WorkOrders.isEmpty ? "No Work Orders found by PF prefix. Confirm the selected site PF prefix matches the child equipment naming convention." : "No Work Orders found for today. Last 30 Days returned records, so the site lookup is working and the issue is likely the scheduled date filter or no work scheduled today.")
            """
        }

        return (displayedWorkOrders, diagnostics)
    }
    #endif

    func fetchTodaysWorkOrders(siteId: String) async throws -> [WorkOrderEntity] {
        let today = Date()
        let workOrders = try await apiClient.fetchWorkOrders(siteId: siteId, scheduledDate: today)
        try repository.upsert(workOrders)
        return try repository.forSite(siteId, scheduledDate: today)
    }
}

@MainActor
struct InspectionFormService {
    let apiClient: SalesforceAPIClient
    let taskRepository: WorkTaskRepository
    let stepRepository: WorkTaskStepRepository
    let draftRepository: LocalStepDraftRepository

    func loadInspection(workOrderId: String) async throws -> (tasks: [WorkTaskEntity], steps: [WorkTaskStepEntity], drafts: [LocalStepDraftEntity]) {
        let taskDTOs = try await apiClient.fetchWorkTasks(workOrderId: workOrderId)
        try taskRepository.upsert(taskDTOs)
        let tasks = try taskRepository.forWorkOrder(workOrderId)
        let taskIds = tasks.map(\WorkTaskEntity.id)
        let stepDTOs = taskIds.isEmpty ? [] : try await apiClient.fetchWorkTaskSteps(workTaskIds: taskIds)
        try stepRepository.upsert(stepDTOs)
        let steps = try stepRepository.forTasks(taskIds)
        try draftRepository.buildDrafts(workOrderId: workOrderId, tasks: tasks, steps: steps)
        return (tasks, steps, try draftRepository.drafts(workOrderId: workOrderId))
    }

    func localInspection(workOrderId: String) throws -> (tasks: [WorkTaskEntity], steps: [WorkTaskStepEntity], drafts: [LocalStepDraftEntity]) {
        let tasks = try taskRepository.forWorkOrder(workOrderId)
        let steps = try stepRepository.forTasks(tasks.map(\WorkTaskEntity.id))
        return (tasks, steps, try draftRepository.drafts(workOrderId: workOrderId))
    }

    func validationErrors(workOrderId: String) throws -> [String] {
        let local = try localInspection(workOrderId: workOrderId)
        return local.steps.compactMap { step in
            guard step.criticalInspection else { return nil }
            let draft = local.drafts.first { $0.workTaskStepId == step.id }
            return draft?.result == StepResult.none ? step.id : nil
        }
    }
}

@MainActor
struct InspectionSyncService {
    let apiClient: SalesforceAPIClient
    let draftRepository: LocalStepDraftRepository

    func markWorkOrderPendingUpload(_ workOrderId: String) throws {
        try draftRepository.markWorkOrderPendingUpload(workOrderId)
    }

    func syncPendingStepUpdates() async throws -> Int {
        let drafts = try draftRepository.pendingDrafts()
        guard drafts.isEmpty == false else { return 0 }
        try await apiClient.refreshTokenIfNeeded()

        var uploadedCount = 0
        var firstSyncError: Error?
        for draft in drafts {
            draft.syncStatus = .uploading
            draft.lastSyncError = nil
            try draftRepository.saveIfNeeded()
            let completedAt = draft.completedAt ?? Date()
            do {
                try await apiClient.updateWorkTaskStep(stepId: draft.workTaskStepId, result: draft.result, comments: draft.comments, complete: true, completedAt: completedAt)
                draft.completedAt = completedAt
                draft.originalResultRawValue = draft.resultRawValue
                draft.originalComments = draft.comments
                draft.syncStatus = .synced
                draft.lastSyncError = nil
                uploadedCount += 1
            } catch {
                draft.syncStatus = .syncError
                draft.lastSyncError = error.localizedDescription
                firstSyncError = firstSyncError ?? error
            }
            try draftRepository.saveIfNeeded()
        }

        if let firstSyncError {
            throw firstSyncError
        }
        return uploadedCount
    }

    func pendingCount() throws -> Int {
        try draftRepository.pendingCount()
    }

    func pendingUploadCount() throws -> Int {
        try draftRepository.pendingUploadCount()
    }

    func syncErrorCount() throws -> Int {
        try draftRepository.syncErrorCount()
    }

    static func isConnectivityError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }
        let code = URLError.Code(rawValue: nsError.code)
        return [
            .notConnectedToInternet,
            .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed
        ].contains(code)
    }
}

@MainActor
struct PhotoUploadService {
    let apiClient: SalesforceAPIClient
    let repository: PendingPhotoUploadRepository

    func queuePhoto(stepId: String, localPath: String) throws {
        let url = URL(fileURLWithPath: localPath)
        try repository.addPhoto(stepId: stepId, fileName: url.lastPathComponent, mimeType: "image/jpeg", localPath: localPath)
    }

    func syncPendingPhotos() async throws -> Int {
        let uploads = try repository.pendingUploads()
        var syncedCount = 0
        for upload in uploads {
            upload.syncStatus = .uploading
            try repository.saveIfNeeded()
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: upload.localPath))
                let contentDocumentId = try await apiClient.uploadContentVersion(fileName: upload.fileName, mimeType: upload.mimeType, data: data)
                try await apiClient.createContentDocumentLink(contentDocumentId: contentDocumentId, linkedEntityId: upload.stepId)
                upload.contentDocumentId = contentDocumentId
                upload.syncStatus = .synced
                upload.lastSyncError = nil
                syncedCount += 1
            } catch {
                upload.syncStatus = .syncError
                upload.lastSyncError = error.localizedDescription
            }
            try repository.saveIfNeeded()
        }
        return syncedCount
    }
}
