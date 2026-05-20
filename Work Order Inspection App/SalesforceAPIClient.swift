import Foundation

struct SalesforceSession: Equatable {
    let accessToken: String
    let instanceURL: URL
    let userId: String
    let expiresAt: Date
}

protocol SalesforceAPIClient {
    func authenticate() async throws -> SalesforceSession
    func fetchSites() async throws -> [SiteDTO]
    func fetchWorkOrders(siteId: String, scheduledDate: Date) async throws -> [WorkOrderDTO]
    func fetchWorkTasks(workOrderId: String) async throws -> [WorkTaskDTO]
    func fetchWorkTaskSteps(workTaskIds: [String]) async throws -> [WorkTaskStepDTO]
    func updateWorkTaskStep(stepId: String, result: StepResult, comments: String, complete: Bool, completedAt: Date) async throws
    func uploadContentVersion(fileName: String, mimeType: String, data: Data) async throws -> String
    func createContentDocumentLink(contentDocumentId: String, linkedEntityId: String) async throws
    func refreshTokenIfNeeded() async throws
}

enum MockSyncFailureMode {
    case none
    case connectivity
    case nonConnectivity
}

struct MockSalesforceAPIClient: SalesforceAPIClient {
    var simulateFetchFailure = false
    var simulateStepUpdateFailure = false
    var simulatedSyncFailure: MockSyncFailureMode = .none
    private let clockDelay: UInt64 = 200_000_000

    func authenticate() async throws -> SalesforceSession {
        try await Task.sleep(nanoseconds: clockDelay)
        return SalesforceSession(accessToken: "mock-access-token", instanceURL: URL(string: "https://mock.salesforce.local")!, userId: "005-MOCK-USER", expiresAt: Date().addingTimeInterval(3600))
    }

    func fetchSites() async throws -> [SiteDTO] {
        try await Task.sleep(nanoseconds: clockDelay)
        try throwFetchFailureIfNeeded()
        return [
            SiteDTO(id: "a10PLANT001", name: "North Solar Plant", assetClass: "Plant", assetSubClass: "Solar", status: "In Service", siteStatus: "Operational", plant: "NSP", plantName: "North Solar Plant", topLevelParent: nil, latitude: 41.88, longitude: -87.63, stateProvince: "IL", nameplateCapacityKW: 12500, uniqueName: "NSP-001", externalAssetId: "EXT-NSP-001", assetUUID: "UUID-NSP-001"),
            SiteDTO(id: "a10PLANT002", name: "West Wind Plant", assetClass: "Plant", assetSubClass: "Wind", status: "In Service", siteStatus: "Operational", plant: "WWP", plantName: "West Wind Plant", topLevelParent: nil, latitude: 42.03, longitude: -88.11, stateProvince: "IL", nameplateCapacityKW: 25000, uniqueName: "WWP-002", externalAssetId: "EXT-WWP-002", assetUUID: "UUID-WWP-002"),
            SiteDTO(id: "a10PLANT003", name: "River Battery Plant", assetClass: "Plant", assetSubClass: "Storage", status: "In Service", siteStatus: "Operational", plant: "RBP", plantName: "River Battery Plant", topLevelParent: nil, latitude: 40.73, longitude: -89.61, stateProvince: "IL", nameplateCapacityKW: 9000, uniqueName: "RBP-003", externalAssetId: "EXT-RBP-003", assetUUID: "UUID-RBP-003")
        ]
    }

    func fetchWorkOrders(siteId: String, scheduledDate: Date) async throws -> [WorkOrderDTO] {
        try await Task.sleep(nanoseconds: clockDelay)
        try throwFetchFailureIfNeeded()
        let today = Calendar.current.startOfDay(for: scheduledDate)
        let orders = [
            WorkOrderDTO(id: "a20WO001", name: "WO-000451", assetId: "a10PLANT001", status: "Open", woStatus: "Scheduled", woType: "Inspection", priority: "High", scheduledStartDate: today, scheduledDateTime: Date(), scheduledOnsiteDate: today, scheduledCompletionDate: nil, siteName: "North Solar Plant", siteType: "Solar", siteAccess: "Gate code in dispatch notes", siteInstructions: "Check in with site operator before entering inverter pad.", workOrder18: "a20WO001000000AAA", recordTypeId: "012MOCKINSPECTION"),
            WorkOrderDTO(id: "a20WO002", name: "WO-000452", assetId: "a10PLANT001", status: "Open", woStatus: "Scheduled", woType: "Inspection", priority: "Medium", scheduledStartDate: today, scheduledDateTime: Date(), scheduledOnsiteDate: today, scheduledCompletionDate: nil, siteName: "North Solar Plant", siteType: "Solar", siteAccess: "Standard access", siteInstructions: "Inspect combiner area after inverter checks.", workOrder18: "a20WO002000000AAA", recordTypeId: "012MOCKINSPECTION"),
            WorkOrderDTO(id: "a20WO003", name: "WO-000601", assetId: "a10PLANT002", status: "Open", woStatus: "Scheduled", woType: "Inspection", priority: "Low", scheduledStartDate: today, scheduledDateTime: Date(), scheduledOnsiteDate: today, scheduledCompletionDate: nil, siteName: "West Wind Plant", siteType: "Wind", siteAccess: "Escort required", siteInstructions: "Call control room on arrival.", workOrder18: "a20WO003000000AAA", recordTypeId: "012MOCKINSPECTION")
        ]
        return orders.filter { $0.assetId == siteId }
    }

    func fetchWorkTasks(workOrderId: String) async throws -> [WorkTaskDTO] {
        try await Task.sleep(nanoseconds: clockDelay)
        try throwFetchFailureIfNeeded()
        let tasks: [String: [WorkTaskDTO]] = [
            "a20WO001": [
                WorkTaskDTO(id: "a30TASK001", name: "Inverter Pad Inspection", workOrderId: "a20WO001", assetId: "a10PLANT001", step: 1, descriptionText: "Inspect inverter pad condition and safety equipment.", status: "Open", scheduleDate: Date(), taskDueDate: Date(), standardFormTemplateId: "a40FORM001", stdTaskId: "a50STD001", totalSteps: 3, taskStepsCompleted: 0, wtType: "Inspection", priority: "High", instructionsRT: "Verify PPE, signage, and inverter condition.", formValuesJSON: nil, inspectionFormCompleted: false),
                WorkTaskDTO(id: "a30TASK002", name: "Combiner Box Inspection", workOrderId: "a20WO001", assetId: "a10PLANT001", step: 2, descriptionText: "Inspect combiner boxes and visible cabling.", status: "Open", scheduleDate: Date(), taskDueDate: Date(), standardFormTemplateId: "a40FORM002", stdTaskId: "a50STD002", totalSteps: 2, taskStepsCompleted: 1, wtType: "Inspection", priority: "Medium", instructionsRT: "Check enclosure condition and labels.", formValuesJSON: nil, inspectionFormCompleted: false)
            ],
            "a20WO002": [
                WorkTaskDTO(id: "a30TASK003", name: "Site Access Review", workOrderId: "a20WO002", assetId: "a10PLANT001", step: 1, descriptionText: "Review access road and gate condition.", status: "Open", scheduleDate: Date(), taskDueDate: Date(), standardFormTemplateId: nil, stdTaskId: nil, totalSteps: 1, taskStepsCompleted: 0, wtType: "Inspection", priority: "Medium", instructionsRT: "Document access constraints.", formValuesJSON: nil, inspectionFormCompleted: false)
            ]
        ]
        return tasks[workOrderId] ?? []
    }

    func fetchWorkTaskSteps(workTaskIds: [String]) async throws -> [WorkTaskStepDTO] {
        try await Task.sleep(nanoseconds: clockDelay)
        try throwFetchFailureIfNeeded()
        let steps = [
            WorkTaskStepDTO(id: "a60STEP001", name: "Verify PPE station", workTaskId: "a30TASK001", sequence: 1, status: "Open", complete: false, criticalInspection: true, userPicklist: nil, userText: nil, value: nil, comments: nil, recommendedAction: nil, additionalDetails: "Confirm PPE cabinet is stocked and accessible.", trackCompleteTime: nil, externalId: "STEP-001"),
            WorkTaskStepDTO(id: "a60STEP002", name: "Inspect inverter enclosure", workTaskId: "a30TASK001", sequence: 2, status: "Open", complete: false, criticalInspection: true, userPicklist: "Pass", userText: nil, value: nil, comments: "No visible damage from prior inspection.", recommendedAction: nil, additionalDetails: "Look for dents, corrosion, loose panels, or open latches.", trackCompleteTime: nil, externalId: "STEP-002"),
            WorkTaskStepDTO(id: "a60STEP003", name: "Confirm safety signage", workTaskId: "a30TASK001", sequence: 3, status: "Open", complete: false, criticalInspection: false, userPicklist: nil, userText: nil, value: nil, comments: nil, recommendedAction: nil, additionalDetails: "Signs should be legible from normal approach path.", trackCompleteTime: nil, externalId: "STEP-003"),
            WorkTaskStepDTO(id: "a60STEP004", name: "Combiner enclosure condition", workTaskId: "a30TASK002", sequence: 1, status: "Open", complete: false, criticalInspection: true, userPicklist: "Fail", userText: nil, value: nil, comments: "Latch was stiff last visit.", recommendedAction: "Lubricate or replace latch", additionalDetails: "Open and close enclosure if safe. Photo recommended when failed.", trackCompleteTime: nil, externalId: "STEP-004"),
            WorkTaskStepDTO(id: "a60STEP005", name: "Cable labeling", workTaskId: "a30TASK002", sequence: 2, status: "Open", complete: false, criticalInspection: false, userPicklist: nil, userText: nil, value: nil, comments: nil, recommendedAction: nil, additionalDetails: "Confirm labels are present and readable.", trackCompleteTime: nil, externalId: "STEP-005"),
            WorkTaskStepDTO(id: "a60STEP006", name: "Gate and road condition", workTaskId: "a30TASK003", sequence: 1, status: "Open", complete: false, criticalInspection: true, userPicklist: nil, userText: nil, value: nil, comments: nil, recommendedAction: nil, additionalDetails: "Record any unsafe access issues.", trackCompleteTime: nil, externalId: "STEP-006")
        ]
        return steps.filter { workTaskIds.contains($0.workTaskId) }
    }

    func updateWorkTaskStep(stepId: String, result: StepResult, comments: String, complete: Bool, completedAt: Date) async throws {
        try await Task.sleep(nanoseconds: clockDelay)
        if simulatedSyncFailure == .connectivity {
            throw URLError(.notConnectedToInternet)
        }
        if simulatedSyncFailure == .nonConnectivity || simulateStepUpdateFailure || comments.localizedCaseInsensitiveContains("simulate sync failure") {
            throw SalesforceAPIError.mockSyncFailure
        }
        _ = (stepId, result, comments, complete, completedAt)
    }

    func uploadContentVersion(fileName: String, mimeType: String, data: Data) async throws -> String {
        try await Task.sleep(nanoseconds: clockDelay)
        _ = (fileName, mimeType, data)
        return "069MOCKCONTENTDOCUMENT"
    }

    func createContentDocumentLink(contentDocumentId: String, linkedEntityId: String) async throws {
        try await Task.sleep(nanoseconds: clockDelay)
        _ = (contentDocumentId, linkedEntityId)
    }

    func refreshTokenIfNeeded() async throws { }

    private func throwFetchFailureIfNeeded() throws {
        if simulateFetchFailure {
            throw SalesforceAPIError.mockFetchFailure
        }
    }
}

final class RealSalesforceAPIClient: SalesforceAPIClient {
    private let urlSession: URLSession
    private var session: SalesforceSession?

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func authenticate() async throws -> SalesforceSession {
        // TODO: Implement OAuth 2.0 Authorization Code with PKCE, Connected App client ID, redirect URI, login domain, scopes, keychain storage, and token refresh.
        throw SalesforceAPIError.notConfigured
    }

    func fetchSites() async throws -> [SiteDTO] {
        _ = try queryRequest(soql: SalesforceSchema.sitesQuery())
        throw SalesforceAPIError.notConfigured
    }

    func fetchWorkOrders(siteId: String, scheduledDate: Date) async throws -> [WorkOrderDTO] {
        _ = try queryRequest(soql: SalesforceSchema.workOrdersForSiteQuery(siteId: siteId, scheduledDate: scheduledDate))
        throw SalesforceAPIError.notConfigured
    }

    func fetchWorkTasks(workOrderId: String) async throws -> [WorkTaskDTO] {
        _ = try queryRequest(soql: SalesforceSchema.workTasksForWorkOrderQuery(workOrderId: workOrderId))
        throw SalesforceAPIError.notConfigured
    }

    func fetchWorkTaskSteps(workTaskIds: [String]) async throws -> [WorkTaskStepDTO] {
        _ = try queryRequest(soql: SalesforceSchema.workTaskStepsForTasksQuery(taskIds: workTaskIds))
        throw SalesforceAPIError.notConfigured
    }

    func updateWorkTaskStep(stepId: String, result: StepResult, comments: String, complete: Bool, completedAt: Date) async throws {
        var request = try authorizedRequest(path: SalesforceSchema.workTaskStepPatchPath(stepId: stepId))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            SalesforceSchema.WorkTaskStepFields.userPicklist: result.salesforceValue,
            SalesforceSchema.WorkTaskStepFields.comments: comments,
            SalesforceSchema.WorkTaskStepFields.complete: complete,
            SalesforceSchema.WorkTaskStepFields.trackCompleteTime: ISO8601DateFormatter.salesforceInternetDateTime.string(from: completedAt)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = (request, urlSession)
        throw SalesforceAPIError.notConfigured
    }

    func uploadContentVersion(fileName: String, mimeType: String, data: Data) async throws -> String {
        var request = try authorizedRequest(path: SalesforceSchema.contentVersionPath())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            SalesforceSchema.ContentVersionFields.title: fileName,
            SalesforceSchema.ContentVersionFields.pathOnClient: fileName,
            SalesforceSchema.ContentVersionFields.versionData: data.base64EncodedString()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = (request, mimeType, urlSession)
        // TODO: Decode ContentVersion response, then query or request ContentDocumentId.
        throw SalesforceAPIError.notConfigured
    }

    func createContentDocumentLink(contentDocumentId: String, linkedEntityId: String) async throws {
        var request = try authorizedRequest(path: SalesforceSchema.contentDocumentLinkPath())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            SalesforceSchema.ContentDocumentLinkFields.contentDocumentId: contentDocumentId,
            SalesforceSchema.ContentDocumentLinkFields.linkedEntityId: linkedEntityId,
            SalesforceSchema.ContentDocumentLinkFields.shareType: SalesforceSchema.ContentDocumentLinkFields.shareTypeViewer,
            SalesforceSchema.ContentDocumentLinkFields.visibility: SalesforceSchema.ContentDocumentLinkFields.visibilityAllUsers
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = (request, urlSession)
        throw SalesforceAPIError.notConfigured
    }

    func refreshTokenIfNeeded() async throws {
        // TODO: Refresh OAuth token before expiry and update secure token storage.
        throw SalesforceAPIError.notConfigured
    }

    private func queryRequest(soql: String) throws -> URLRequest {
        guard var components = URLComponents(url: try instanceURL().appending(path: "/services/data/\(SalesforceSchema.apiVersion)/query"), resolvingAgainstBaseURL: false) else {
            throw SalesforceAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "q", value: soql)]
        guard let url = components.url else { throw SalesforceAPIError.invalidURL }
        return try authorizedRequest(url: url)
    }

    private func authorizedRequest(path: String) throws -> URLRequest {
        try authorizedRequest(url: instanceURL().appending(path: path))
    }

    private func authorizedRequest(url: URL) throws -> URLRequest {
        guard let session else { throw SalesforceAPIError.notAuthenticated }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func instanceURL() throws -> URL {
        guard let session else { throw SalesforceAPIError.notAuthenticated }
        return session.instanceURL
    }
}

enum SalesforceAPIError: LocalizedError {
    case notAuthenticated
    case notConfigured
    case invalidURL
    case mockFetchFailure
    case mockSyncFailure

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Salesforce session is not authenticated."
        case .notConfigured: "Real Salesforce integration is not configured yet. Use MockSalesforceAPIClient for local app runs."
        case .invalidURL: "Could not build Salesforce REST URL."
        case .mockFetchFailure: "Mock fetch failure. Disable simulateFetchFailure and try again."
        case .mockSyncFailure: "Mock sync failure. Remove 'simulate sync failure' from comments and retry."
        }
    }
}
