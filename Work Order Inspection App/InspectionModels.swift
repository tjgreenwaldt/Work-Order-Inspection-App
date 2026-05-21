import Foundation
import SwiftData

enum StepResult: String, Codable, CaseIterable, Identifiable {
    case none
    case pass
    case fail

    var id: String { rawValue }

    var salesforceValue: String {
        switch self {
        case .none: SalesforceSchema.Picklists.none
        case .pass: SalesforceSchema.Picklists.pass
        case .fail: SalesforceSchema.Picklists.fail
        }
    }

    var title: String { salesforceValue }

    init(salesforceValue: String?) {
        switch salesforceValue {
        case SalesforceSchema.Picklists.pass: self = .pass
        case SalesforceSchema.Picklists.fail: self = .fail
        default: self = .none
        }
    }
}

enum SyncStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case pendingUpload
    case uploading
    case synced
    case syncError

    var id: String { rawValue }
}

struct SalesforceFileUploadDTO: Identifiable, Codable, Equatable {
    let id: UUID
    let stepId: String
    let fileName: String
    let mimeType: String
    let localPath: String
    let contentDocumentId: String?
    let syncStatus: SyncStatus
    let lastSyncError: String?
}

struct SiteDTO: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let friendlyName: String?
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
}

extension SiteDTO {
    var displayName: String {
        let trimmedFriendlyName = friendlyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedFriendlyName.isEmpty ? SiteNameDisplay.readableFallback(from: name) : trimmedFriendlyName
    }

    var pfIdPrefix: String {
        sitePfIdPrefix(from: name)
    }
}

struct WorkOrderDTO: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let assetId: String
    let assetName: String?
    let descriptionText: String?
    let assetDescription: String?
    let accountId: String?
    let accountSR: String?
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
}

struct WorkTaskDTO: Identifiable, Codable, Equatable {
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
}

struct WorkTaskStepDTO: Identifiable, Codable, Equatable {
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
}

@Model
final class SiteEntity {
    @Attribute(.unique) var id: String
    var name: String
    var friendlyName: String?
    var assetClass: String
    var assetSubClass: String?
    var status: String
    var siteStatus: String?
    var plant: String?
    var plantName: String?
    var topLevelParent: String?
    var latitude: Double?
    var longitude: Double?
    var stateProvince: String?
    var nameplateCapacityKW: Double?
    var uniqueName: String?
    var externalAssetId: String?
    var assetUUID: String?

    init(dto: SiteDTO) {
        self.id = dto.id
        self.name = dto.name
        self.friendlyName = dto.friendlyName
        self.assetClass = dto.assetClass
        self.assetSubClass = dto.assetSubClass
        self.status = dto.status
        self.siteStatus = dto.siteStatus
        self.plant = dto.plant
        self.plantName = dto.plantName
        self.topLevelParent = dto.topLevelParent
        self.latitude = dto.latitude
        self.longitude = dto.longitude
        self.stateProvince = dto.stateProvince
        self.nameplateCapacityKW = dto.nameplateCapacityKW
        self.uniqueName = dto.uniqueName
        self.externalAssetId = dto.externalAssetId
        self.assetUUID = dto.assetUUID
    }
}

extension SiteEntity {
    var displayName: String {
        let trimmedFriendlyName = friendlyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedFriendlyName.isEmpty ? SiteNameDisplay.readableFallback(from: name) : trimmedFriendlyName
    }

    var pfIdPrefix: String {
        sitePfIdPrefix(from: name)
    }
}

enum SiteNameDisplay {
    static func readableFallback(from equipmentName: String) -> String {
        let trimmedName = equipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = sitePfIdPrefix(from: trimmedName)
        var remainder = trimmedName

        if remainder.hasPrefix(prefix) {
            remainder.removeFirst(prefix.count)
        }
        if remainder.hasPrefix(".") {
            remainder.removeFirst()
        }
        if let plantRange = remainder.range(of: ".Plant") {
            remainder = String(remainder[..<plantRange.lowerBound])
        } else if let plantRange = remainder.range(of: "Plant") {
            remainder = String(remainder[..<plantRange.lowerBound])
        }

        let cleaned = remainder
            .replacingOccurrences(of: ".", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? prefix : cleaned
    }
}

@Model
final class WorkOrderEntity {
    @Attribute(.unique) var id: String
    var name: String
    var assetId: String
    var assetName: String?
    var descriptionText: String?
    var assetDescription: String?
    var accountId: String?
    var accountSR: String?
    var status: String?
    var woStatus: String?
    var woType: String?
    var priority: String?
    var scheduledStartDate: Date
    var scheduledDateTime: Date?
    var scheduledOnsiteDate: Date?
    var scheduledCompletionDate: Date?
    var siteName: String?
    var siteType: String?
    var siteAccess: String?
    var siteInstructions: String?
    var workOrder18: String?
    var recordTypeId: String?

    init(dto: WorkOrderDTO) {
        self.id = dto.id
        self.name = dto.name
        self.assetId = dto.assetId
        self.assetName = dto.assetName
        self.descriptionText = dto.descriptionText
        self.assetDescription = dto.assetDescription
        self.accountId = dto.accountId
        self.accountSR = dto.accountSR
        self.status = dto.status
        self.woStatus = dto.woStatus
        self.woType = dto.woType
        self.priority = dto.priority
        self.scheduledStartDate = dto.scheduledStartDate
        self.scheduledDateTime = dto.scheduledDateTime
        self.scheduledOnsiteDate = dto.scheduledOnsiteDate
        self.scheduledCompletionDate = dto.scheduledCompletionDate
        self.siteName = dto.siteName
        self.siteType = dto.siteType
        self.siteAccess = dto.siteAccess
        self.siteInstructions = dto.siteInstructions
        self.workOrder18 = dto.workOrder18
        self.recordTypeId = dto.recordTypeId
    }
}

@Model
final class WorkTaskEntity {
    @Attribute(.unique) var id: String
    var name: String
    var workOrderId: String
    var assetId: String?
    var step: Double?
    var descriptionText: String?
    var status: String?
    var scheduleDate: Date?
    var taskDueDate: Date?
    var standardFormTemplateId: String?
    var stdTaskId: String?
    var totalSteps: Int?
    var taskStepsCompleted: Int?
    var wtType: String?
    var priority: String?
    var instructionsRT: String?
    var formValuesJSON: String?
    var inspectionFormCompleted: Bool?

    init(dto: WorkTaskDTO) {
        self.id = dto.id
        self.name = dto.name
        self.workOrderId = dto.workOrderId
        self.assetId = dto.assetId
        self.step = dto.step
        self.descriptionText = dto.descriptionText
        self.status = dto.status
        self.scheduleDate = dto.scheduleDate
        self.taskDueDate = dto.taskDueDate
        self.standardFormTemplateId = dto.standardFormTemplateId
        self.stdTaskId = dto.stdTaskId
        self.totalSteps = dto.totalSteps
        self.taskStepsCompleted = dto.taskStepsCompleted
        self.wtType = dto.wtType
        self.priority = dto.priority
        self.instructionsRT = dto.instructionsRT
        self.formValuesJSON = dto.formValuesJSON
        self.inspectionFormCompleted = dto.inspectionFormCompleted
    }
}

@Model
final class WorkTaskStepEntity {
    @Attribute(.unique) var id: String
    var name: String
    var workTaskId: String
    var sequence: Double?
    var status: String?
    var complete: Bool
    var criticalInspection: Bool
    var userPicklist: String?
    var userText: String?
    var value: Double?
    var comments: String?
    var recommendedAction: String?
    var additionalDetails: String?
    var trackCompleteTime: Date?
    var externalId: String?

    init(dto: WorkTaskStepDTO) {
        self.id = dto.id
        self.name = dto.name
        self.workTaskId = dto.workTaskId
        self.sequence = dto.sequence
        self.status = dto.status
        self.complete = dto.complete
        self.criticalInspection = dto.criticalInspection
        self.userPicklist = dto.userPicklist
        self.userText = dto.userText
        self.value = dto.value
        self.comments = dto.comments
        self.recommendedAction = dto.recommendedAction
        self.additionalDetails = dto.additionalDetails
        self.trackCompleteTime = dto.trackCompleteTime
        self.externalId = dto.externalId
    }
}

@Model
final class LocalStepDraftEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var draftKey: String?
    var workOrderId: String
    var workTaskId: String
    var workTaskStepId: String
    var resultRawValue: String
    var originalResultRawValue: String?
    var comments: String
    var originalComments: String?
    var localPhotoPath: String?
    var completedAt: Date?
    var syncStatusRawValue: String
    var lastSyncError: String?

    var result: StepResult {
        get { StepResult(rawValue: resultRawValue) ?? .none }
        set { resultRawValue = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRawValue) ?? .draft }
        set { syncStatusRawValue = newValue.rawValue }
    }

    var hasChangesForUpload: Bool {
        resultRawValue != (originalResultRawValue ?? resultRawValue) ||
        comments != (originalComments ?? comments)
    }

    init(id: UUID = UUID(), workOrderId: String, workTaskId: String, workTaskStepId: String, result: StepResult, comments: String = "", localPhotoPath: String? = nil, completedAt: Date? = nil, syncStatus: SyncStatus = .draft, lastSyncError: String? = nil) {
        self.id = id
        self.draftKey = Self.makeDraftKey(workOrderId: workOrderId, stepId: workTaskStepId)
        self.workOrderId = workOrderId
        self.workTaskId = workTaskId
        self.workTaskStepId = workTaskStepId
        self.resultRawValue = result.rawValue
        self.originalResultRawValue = result.rawValue
        self.comments = comments
        self.originalComments = comments
        self.localPhotoPath = localPhotoPath
        self.completedAt = completedAt
        self.syncStatusRawValue = syncStatus.rawValue
        self.lastSyncError = lastSyncError
    }

    static func makeDraftKey(workOrderId: String, stepId: String) -> String {
        "\(workOrderId)|\(stepId)"
    }
}

@Model
final class PendingPhotoUploadEntity {
    @Attribute(.unique) var id: UUID
    var stepId: String
    var fileName: String
    var mimeType: String
    var localPath: String
    var contentDocumentId: String?
    var syncStatusRawValue: String
    var lastSyncError: String?

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRawValue) ?? .draft }
        set { syncStatusRawValue = newValue.rawValue }
    }

    init(id: UUID = UUID(), stepId: String, fileName: String, mimeType: String, localPath: String, contentDocumentId: String? = nil, syncStatus: SyncStatus = .draft, lastSyncError: String? = nil) {
        self.id = id
        self.stepId = stepId
        self.fileName = fileName
        self.mimeType = mimeType
        self.localPath = localPath
        self.contentDocumentId = contentDocumentId
        self.syncStatusRawValue = syncStatus.rawValue
        self.lastSyncError = lastSyncError
    }
}

extension SiteEntity {
    func update(from dto: SiteDTO) {
        name = dto.name
        friendlyName = dto.friendlyName
        assetClass = dto.assetClass
        assetSubClass = dto.assetSubClass
        status = dto.status
        siteStatus = dto.siteStatus
        plant = dto.plant
        plantName = dto.plantName
        topLevelParent = dto.topLevelParent
        latitude = dto.latitude
        longitude = dto.longitude
        stateProvince = dto.stateProvince
        nameplateCapacityKW = dto.nameplateCapacityKW
        uniqueName = dto.uniqueName
        externalAssetId = dto.externalAssetId
        assetUUID = dto.assetUUID
    }

    var dto: SiteDTO {
        SiteDTO(id: id, name: name, friendlyName: friendlyName, assetClass: assetClass, assetSubClass: assetSubClass, status: status, siteStatus: siteStatus, plant: plant, plantName: plantName, topLevelParent: topLevelParent, latitude: latitude, longitude: longitude, stateProvince: stateProvince, nameplateCapacityKW: nameplateCapacityKW, uniqueName: uniqueName, externalAssetId: externalAssetId, assetUUID: assetUUID)
    }
}

extension WorkOrderEntity {
    func update(from dto: WorkOrderDTO) {
        name = dto.name
        assetId = dto.assetId
        assetName = dto.assetName
        descriptionText = dto.descriptionText
        assetDescription = dto.assetDescription
        accountId = dto.accountId
        accountSR = dto.accountSR
        status = dto.status
        woStatus = dto.woStatus
        woType = dto.woType
        priority = dto.priority
        scheduledStartDate = dto.scheduledStartDate
        scheduledDateTime = dto.scheduledDateTime
        scheduledOnsiteDate = dto.scheduledOnsiteDate
        scheduledCompletionDate = dto.scheduledCompletionDate
        siteName = dto.siteName
        siteType = dto.siteType
        siteAccess = dto.siteAccess
        siteInstructions = dto.siteInstructions
        workOrder18 = dto.workOrder18
        recordTypeId = dto.recordTypeId
    }

    var dto: WorkOrderDTO {
        WorkOrderDTO(id: id, name: name, assetId: assetId, assetName: assetName, descriptionText: descriptionText, assetDescription: assetDescription, accountId: accountId, accountSR: accountSR, status: status, woStatus: woStatus, woType: woType, priority: priority, scheduledStartDate: scheduledStartDate, scheduledDateTime: scheduledDateTime, scheduledOnsiteDate: scheduledOnsiteDate, scheduledCompletionDate: scheduledCompletionDate, siteName: siteName, siteType: siteType, siteAccess: siteAccess, siteInstructions: siteInstructions, workOrder18: workOrder18, recordTypeId: recordTypeId)
    }
}

extension WorkTaskEntity {
    func update(from dto: WorkTaskDTO) {
        name = dto.name
        workOrderId = dto.workOrderId
        assetId = dto.assetId
        step = dto.step
        descriptionText = dto.descriptionText
        status = dto.status
        scheduleDate = dto.scheduleDate
        taskDueDate = dto.taskDueDate
        standardFormTemplateId = dto.standardFormTemplateId
        stdTaskId = dto.stdTaskId
        totalSteps = dto.totalSteps
        taskStepsCompleted = dto.taskStepsCompleted
        wtType = dto.wtType
        priority = dto.priority
        instructionsRT = dto.instructionsRT
        formValuesJSON = dto.formValuesJSON
        inspectionFormCompleted = dto.inspectionFormCompleted
    }
}

extension WorkTaskStepEntity {
    func update(from dto: WorkTaskStepDTO) {
        name = dto.name
        workTaskId = dto.workTaskId
        sequence = dto.sequence
        status = dto.status
        complete = dto.complete
        criticalInspection = dto.criticalInspection
        userPicklist = dto.userPicklist
        userText = dto.userText
        value = dto.value
        comments = dto.comments
        recommendedAction = dto.recommendedAction
        additionalDetails = dto.additionalDetails
        trackCompleteTime = dto.trackCompleteTime
        externalId = dto.externalId
    }
}
