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
    private let config: SalesforceConfig
    private let urlSession: URLSession
    private var session: SalesforceSession?

    init(config: SalesforceConfig = .current, session: SalesforceSession? = nil, urlSession: URLSession = .shared) {
        self.config = config
        self.session = session
        self.urlSession = urlSession
    }

    func authenticate() async throws -> SalesforceSession {
        // TODO: Implement OAuth 2.0 Authorization Code with PKCE, Connected App client ID, redirect URI, login domain, scopes, keychain storage, and token refresh.
        guard let session else {
            throw SalesforceAPIError.sessionNotConfigured
        }
        return session
    }

    func fetchSites() async throws -> [SiteDTO] {
        try await executeQuery(SalesforceSchema.sitesQuery(), as: SalesforceSiteRecord.self) { $0.dto }
    }

    func fetchWorkOrders(siteId: String, scheduledDate: Date) async throws -> [WorkOrderDTO] {
        try await executeQuery(SalesforceSchema.workOrdersForSiteQuery(siteId: siteId, scheduledDate: scheduledDate), as: SalesforceWorkOrderRecord.self) { $0.dto }
    }

    func fetchWorkTasks(workOrderId: String) async throws -> [WorkTaskDTO] {
        try await executeQuery(SalesforceSchema.workTasksForWorkOrderQuery(workOrderId: workOrderId), as: SalesforceWorkTaskRecord.self) { $0.dto }
    }

    func fetchWorkTaskSteps(workTaskIds: [String]) async throws -> [WorkTaskStepDTO] {
        guard workTaskIds.isEmpty == false else { return [] }
        return try await executeQuery(SalesforceSchema.workTaskStepsForTasksQuery(taskIds: workTaskIds), as: SalesforceWorkTaskStepRecord.self) { $0.dto }
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

    private func executeQuery<Record: Decodable, Output>(_ soql: String, as recordType: Record.Type, map: (Record) throws -> Output) async throws -> [Output] {
        #if DEBUG
        print("Salesforce SOQL: \(soql)")
        #endif

        let request = try queryRequest(soql: soql)
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SalesforceAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SalesforceAPIError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }

        do {
            let queryResponse = try JSONDecoder.salesforce.decode(SalesforceQueryResponse<Record>.self, from: data)
            return try queryResponse.records.map(map)
        } catch {
            #if DEBUG
            let body = String(data: data, encoding: .utf8) ?? ""
            print("Salesforce decode failed: \(error)")
            print("Salesforce response body: \(body)")
            #endif
            throw SalesforceAPIError.decodingFailed(error.localizedDescription)
        }
    }

    private func queryRequest(soql: String) throws -> URLRequest {
        guard var components = URLComponents(url: try instanceURL(), resolvingAgainstBaseURL: false) else {
            throw SalesforceAPIError.invalidURL
        }
        components.path = "/services/data/\(config.apiVersion)/query"
        components.queryItems = [URLQueryItem(name: "q", value: soql)]
        guard let url = components.url else { throw SalesforceAPIError.invalidURL }
        var request = try authorizedRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func authorizedRequest(path: String) throws -> URLRequest {
        try authorizedRequest(url: instanceURL().appending(path: path))
    }

    private func authorizedRequest(url: URL) throws -> URLRequest {
        guard let session else { throw SalesforceAPIError.sessionNotConfigured }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func instanceURL() throws -> URL {
        guard let session else { throw SalesforceAPIError.sessionNotConfigured }
        return session.instanceURL
    }
}

struct SalesforceQueryResponse<Record: Decodable>: Decodable {
    let totalSize: Int
    let done: Bool
    let records: [Record]
}

private struct SalesforceAttributes: Decodable {
    let type: String?
    let url: String?
}

private struct SalesforceSiteRecord: Decodable {
    let attributes: SalesforceAttributes?
    let id: String
    let name: String
    let assetClass: String
    let assetSubClass: String?
    let status: String
    let siteStatus: String?
    let plant: String?
    let plantName: String?
    let topLevelParent: String?
    let latitude: Double?
    let longitude: Double?
    let stateProvince: String?
    let nameplateCapacityKW: Double?
    let uniqueName: String?
    let externalAssetId: String?
    let assetUUID: String?

    enum CodingKeys: String, CodingKey {
        case attributes
        case id = "Id"
        case name = "Name"
        case assetClass = "pffsm__Asset_Class__c"
        case assetSubClass = "pffsm__Asset_SubClass__c"
        case status = "pffsm__Status__c"
        case siteStatus = "pffsm__Site_Status__c"
        case plant = "pffsm__Plant__c"
        case plantName = "pffsm__PlantName__c"
        case topLevelParent = "pffsm__Top_Level_Parent__c"
        case latitude = "pffsm__Geolocation__Latitude__s"
        case longitude = "pffsm__Geolocation__Longitude__s"
        case stateProvince = "pffsm__State_Province__c"
        case nameplateCapacityKW = "pffsm__Site_Nameplate_Capacity_kW__c"
        case uniqueName = "pffsm__Unique_Name__c"
        case externalAssetId = "pffsm__External_Asset_ID__c"
        case assetUUID = "pffsm__Asset_UUID__c"
    }

    var dto: SiteDTO {
        SiteDTO(id: id, name: name, assetClass: assetClass, assetSubClass: assetSubClass, status: status, siteStatus: siteStatus, plant: plant, plantName: plantName, topLevelParent: topLevelParent, latitude: latitude, longitude: longitude, stateProvince: stateProvince, nameplateCapacityKW: nameplateCapacityKW, uniqueName: uniqueName, externalAssetId: externalAssetId, assetUUID: assetUUID)
    }
}

private struct SalesforceWorkOrderRecord: Decodable {
    let attributes: SalesforceAttributes?
    let id: String
    let name: String
    let assetId: String
    let status: String?
    let woStatus: String?
    let woType: String?
    let priority: String?
    let scheduledStartDate: Date
    let scheduledDateTime: Date?
    let scheduledOnsiteDate: Date?
    let scheduledCompletionDate: Date?
    let siteName: String?
    let siteType: String?
    let siteAccess: String?
    let siteInstructions: String?
    let workOrder18: String?
    let recordTypeId: String?

    enum CodingKeys: String, CodingKey {
        case attributes
        case id = "Id"
        case name = "Name"
        case assetId = "pffsm__Asset__c"
        case status = "pffsm__Status__c"
        case woStatus = "pffsm__WO_Status__c"
        case woType = "pffsm__WO_Type__c"
        case priority = "pffsm__Priority__c"
        case scheduledStartDate = "pffsm__Scheduled_Start_Date__c"
        case scheduledDateTime = "pffsm__Scheduled_Date_Time__c"
        case scheduledOnsiteDate = "pffsm__Scheduled_Onsite_Date__c"
        case scheduledCompletionDate = "pffsm__Scheduled_Completion_Date__c"
        case siteName = "pffsm__Site_Name__c"
        case siteType = "pffsm__Site_Type__c"
        case siteAccess = "pffsm__Site_Access__c"
        case siteInstructions = "pffsm__Site_Instructions__c"
        case workOrder18 = "pffsm__Work_Order_18__c"
        case recordTypeId = "RecordTypeId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try container.decodeIfPresent(SalesforceAttributes.self, forKey: .attributes)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        assetId = try container.decode(String.self, forKey: .assetId)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        woStatus = try container.decodeIfPresent(String.self, forKey: .woStatus)
        woType = try container.decodeIfPresent(String.self, forKey: .woType)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        scheduledStartDate = try container.decodeSalesforceDate(forKey: .scheduledStartDate) ?? Date.distantPast
        scheduledDateTime = try container.decodeSalesforceDate(forKey: .scheduledDateTime)
        scheduledOnsiteDate = try container.decodeSalesforceDate(forKey: .scheduledOnsiteDate)
        scheduledCompletionDate = try container.decodeSalesforceDate(forKey: .scheduledCompletionDate)
        siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        siteType = try container.decodeIfPresent(String.self, forKey: .siteType)
        siteAccess = try container.decodeIfPresent(String.self, forKey: .siteAccess)
        siteInstructions = try container.decodeIfPresent(String.self, forKey: .siteInstructions)
        workOrder18 = try container.decodeIfPresent(String.self, forKey: .workOrder18)
        recordTypeId = try container.decodeIfPresent(String.self, forKey: .recordTypeId)
    }

    var dto: WorkOrderDTO {
        WorkOrderDTO(id: id, name: name, assetId: assetId, status: status, woStatus: woStatus, woType: woType, priority: priority, scheduledStartDate: scheduledStartDate, scheduledDateTime: scheduledDateTime, scheduledOnsiteDate: scheduledOnsiteDate, scheduledCompletionDate: scheduledCompletionDate, siteName: siteName, siteType: siteType, siteAccess: siteAccess, siteInstructions: siteInstructions, workOrder18: workOrder18, recordTypeId: recordTypeId)
    }
}

private struct SalesforceWorkTaskRecord: Decodable {
    let attributes: SalesforceAttributes?
    let id: String
    let name: String
    let workOrderId: String
    let assetId: String?
    let step: Double?
    let descriptionText: String?
    let status: String?
    let scheduleDate: Date?
    let taskDueDate: Date?
    let standardFormTemplateId: String?
    let stdTaskId: String?
    let totalSteps: Int?
    let taskStepsCompleted: Int?
    let wtType: String?
    let priority: String?
    let instructionsRT: String?
    let formValuesJSON: String?
    let inspectionFormCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case attributes
        case id = "Id"
        case name = "Name"
        case workOrderId = "pffsm__Work_Order__c"
        case assetId = "pffsm__Asset__c"
        case step = "pffsm__Step__c"
        case descriptionText = "pffsm__Description__c"
        case status = "pffsm__Status__c"
        case scheduleDate = "pffsm__Schedule_Date__c"
        case taskDueDate = "pffsm__Task_Due_Date__c"
        case standardFormTemplateId = "pffsm__Standard_Form_Template__c"
        case stdTaskId = "pffsm__Std_Task__c"
        case totalSteps = "pffsm__Total_Steps__c"
        case taskStepsCompleted = "pffsm__Task_steps_completed__c"
        case wtType = "pffsm__WT_Type__c"
        case priority = "pffsm__Priority__c"
        case instructionsRT = "pffsm__InstructionsRT__c"
        case formValuesJSON = "pffsm__Form_Values_JSON__c"
        case inspectionFormCompleted = "pffsm__Inspection_Form_Completed__c"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try container.decodeIfPresent(SalesforceAttributes.self, forKey: .attributes)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        workOrderId = try container.decode(String.self, forKey: .workOrderId)
        assetId = try container.decodeIfPresent(String.self, forKey: .assetId)
        step = try container.decodeIfPresent(Double.self, forKey: .step)
        descriptionText = try container.decodeIfPresent(String.self, forKey: .descriptionText)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        scheduleDate = try container.decodeSalesforceDate(forKey: .scheduleDate)
        taskDueDate = try container.decodeSalesforceDate(forKey: .taskDueDate)
        standardFormTemplateId = try container.decodeIfPresent(String.self, forKey: .standardFormTemplateId)
        stdTaskId = try container.decodeIfPresent(String.self, forKey: .stdTaskId)
        totalSteps = try container.decodeFlexibleInt(forKey: .totalSteps)
        taskStepsCompleted = try container.decodeFlexibleInt(forKey: .taskStepsCompleted)
        wtType = try container.decodeIfPresent(String.self, forKey: .wtType)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        instructionsRT = try container.decodeIfPresent(String.self, forKey: .instructionsRT)
        formValuesJSON = try container.decodeIfPresent(String.self, forKey: .formValuesJSON)
        inspectionFormCompleted = try container.decodeIfPresent(Bool.self, forKey: .inspectionFormCompleted)
    }

    var dto: WorkTaskDTO {
        WorkTaskDTO(id: id, name: name, workOrderId: workOrderId, assetId: assetId, step: step, descriptionText: descriptionText, status: status, scheduleDate: scheduleDate, taskDueDate: taskDueDate, standardFormTemplateId: standardFormTemplateId, stdTaskId: stdTaskId, totalSteps: totalSteps, taskStepsCompleted: taskStepsCompleted, wtType: wtType, priority: priority, instructionsRT: instructionsRT, formValuesJSON: formValuesJSON, inspectionFormCompleted: inspectionFormCompleted)
    }
}

private struct SalesforceWorkTaskStepRecord: Decodable {
    let attributes: SalesforceAttributes?
    let id: String
    let name: String
    let workTaskId: String
    let sequence: Double?
    let status: String?
    let complete: Bool
    let criticalInspection: Bool
    let userPicklist: String?
    let userText: String?
    let value: Double?
    let comments: String?
    let recommendedAction: String?
    let additionalDetails: String?
    let trackCompleteTime: Date?
    let externalId: String?

    enum CodingKeys: String, CodingKey {
        case attributes
        case id = "Id"
        case name = "Name"
        case workTaskId = "pffsm__Work_Task__c"
        case sequence = "pffsm__Sequence__c"
        case status = "pffsm__Status__c"
        case complete = "pffsm__Complete__c"
        case criticalInspection = "pffsm__Critical_Inspection__c"
        case userPicklist = "pffsm__User_Picklist__c"
        case userText = "pffsm__User_Text__c"
        case value = "pffsm__Value__c"
        case comments = "pffsm__Comments__c"
        case recommendedAction = "pffsm__Recommended_Action__c"
        case additionalDetails = "pffsm__Additional_Details__c"
        case trackCompleteTime = "pffsm__Track_Complete_Time__c"
        case externalId = "pffsm__PF_External_Id__c"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try container.decodeIfPresent(SalesforceAttributes.self, forKey: .attributes)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        workTaskId = try container.decode(String.self, forKey: .workTaskId)
        sequence = try container.decodeIfPresent(Double.self, forKey: .sequence)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        complete = try container.decodeIfPresent(Bool.self, forKey: .complete) ?? false
        criticalInspection = try container.decodeIfPresent(Bool.self, forKey: .criticalInspection) ?? false
        userPicklist = try container.decodeIfPresent(String.self, forKey: .userPicklist)
        userText = try container.decodeIfPresent(String.self, forKey: .userText)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
        comments = try container.decodeIfPresent(String.self, forKey: .comments)
        recommendedAction = try container.decodeIfPresent(String.self, forKey: .recommendedAction)
        additionalDetails = try container.decodeIfPresent(String.self, forKey: .additionalDetails)
        trackCompleteTime = try container.decodeSalesforceDate(forKey: .trackCompleteTime)
        externalId = try container.decodeIfPresent(String.self, forKey: .externalId)
    }

    var dto: WorkTaskStepDTO {
        WorkTaskStepDTO(id: id, name: name, workTaskId: workTaskId, sequence: sequence, status: status, complete: complete, criticalInspection: criticalInspection, userPicklist: userPicklist, userText: userText, value: value, comments: comments, recommendedAction: recommendedAction, additionalDetails: additionalDetails, trackCompleteTime: trackCompleteTime, externalId: externalId)
    }
}

private extension JSONDecoder {
    static let salesforce: JSONDecoder = JSONDecoder()
}

private extension KeyedDecodingContainer {
    func decodeSalesforceDate(forKey key: Key) throws -> Date? {
        guard let value = try decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        return SalesforceDateParser.parse(value)
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}

private enum SalesforceDateParser {
    static func parse(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter.salesforceInternetDateTime.date(from: value) {
            return date
        }
        if let date = ISO8601DateFormatter.salesforceInternetDateTimeNoFraction.date(from: value) {
            return date
        }
        return DateFormatter.salesforceDateOnly.date(from: value)
    }
}

private extension ISO8601DateFormatter {
    static let salesforceInternetDateTimeNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension DateFormatter {
    static let salesforceDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum SalesforceAPIError: LocalizedError {
    case notAuthenticated
    case sessionNotConfigured
    case notConfigured
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, body: String)
    case decodingFailed(String)
    case mockFetchFailure
    case mockSyncFailure

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Salesforce session is not authenticated."
        case .sessionNotConfigured: "Salesforce session is not configured."
        case .notConfigured: "Real Salesforce integration is not configured yet. Use MockSalesforceAPIClient for local app runs."
        case .invalidURL: "Could not build Salesforce REST URL."
        case .invalidResponse: "Salesforce returned an invalid response."
        case let .requestFailed(statusCode, body): "Salesforce request failed with HTTP \(statusCode). \(body)"
        case let .decodingFailed(message): "Could not decode Salesforce response. \(message)"
        case .mockFetchFailure: "Mock fetch failure. Disable simulateFetchFailure and try again."
        case .mockSyncFailure: "Mock sync failure. Remove 'simulate sync failure' from comments and retry."
        }
    }
}
