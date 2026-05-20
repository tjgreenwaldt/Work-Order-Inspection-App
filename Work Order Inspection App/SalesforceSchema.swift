import Foundation

enum SalesforceSchema {
    static let apiVersion = "v60.0"

    enum Objects {
        static let site = "pffsm__smEquipment__c"
        static let workOrder = "pffsm__smWork_Order__c"
        static let workTask = "pffsm__smWO_Task__c"
        static let workTaskStep = "pffsm__Work_Task_Step__c"
        static let contentVersion = "ContentVersion"
        static let contentDocumentLink = "ContentDocumentLink"
    }

    enum SiteFields {
        static let id = "Id"
        static let name = "Name"
        static let assetClass = "pffsm__Asset_Class__c"
        static let assetSubClass = "pffsm__Asset_SubClass__c"
        static let status = "pffsm__Status__c"
        static let siteStatus = "pffsm__Site_Status__c"
        static let plant = "pffsm__Plant__c"
        static let plantName = "pffsm__PlantName__c"
        static let parent = "pffsm__Parent__c"
        static let topLevelParent = "pffsm__Top_Level_Parent__c"
        static let latitude = "pffsm__Geolocation__Latitude__s"
        static let longitude = "pffsm__Geolocation__Longitude__s"
        static let stateProvince = "pffsm__State_Province__c"
        static let nameplateCapacityKW = "pffsm__Site_Nameplate_Capacity_kW__c"
        static let uniqueName = "pffsm__Unique_Name__c"
        static let externalAssetId = "pffsm__External_Asset_ID__c"
        static let assetUUID = "pffsm__Asset_UUID__c"
    }

    enum WorkOrderFields {
        static let id = "Id"
        static let name = "Name"
        static let assetId = "pffsm__Asset__c"
        static let status = "pffsm__Status__c"
        static let woStatus = "pffsm__WO_Status__c"
        static let woType = "pffsm__WO_Type__c"
        static let priority = "pffsm__Priority__c"
        static let scheduledStartDate = "pffsm__Scheduled_Start_Date__c"
        static let scheduledDateTime = "pffsm__Scheduled_Date_Time__c"
        static let scheduledOnsiteDate = "pffsm__Scheduled_Onsite_Date__c"
        static let scheduledCompletionDate = "pffsm__Scheduled_Completion_Date__c"
        static let siteName = "pffsm__Site_Name__c"
        static let siteType = "pffsm__Site_Type__c"
        static let siteAccess = "pffsm__Site_Access__c"
        static let siteInstructions = "pffsm__Site_Instructions__c"
        static let workOrder18 = "pffsm__Work_Order_18__c"
        static let recordTypeId = "RecordTypeId"
    }

    enum WorkTaskFields {
        static let id = "Id"
        static let name = "Name"
        static let workOrderId = "pffsm__Work_Order__c"
        static let assetId = "pffsm__Asset__c"
        static let step = "pffsm__Step__c"
        static let description = "pffsm__Description__c"
        static let status = "pffsm__Status__c"
        static let scheduleDate = "pffsm__Schedule_Date__c"
        static let taskDueDate = "pffsm__Task_Due_Date__c"
        static let standardFormTemplate = "pffsm__Standard_Form_Template__c"
        static let stdTask = "pffsm__Std_Task__c"
        static let totalSteps = "pffsm__Total_Steps__c"
        static let taskStepsCompleted = "pffsm__Task_steps_completed__c"
        static let wtType = "pffsm__WT_Type__c"
        static let priority = "pffsm__Priority__c"
        static let instructionsRT = "pffsm__InstructionsRT__c"
        static let formValuesJSON = "pffsm__Form_Values_JSON__c"
        static let inspectionFormCompleted = "pffsm__Inspection_Form_Completed__c"
    }

    enum WorkTaskStepFields {
        static let id = "Id"
        static let name = "Name"
        static let workTaskId = "pffsm__Work_Task__c"
        static let sequence = "pffsm__Sequence__c"
        static let status = "pffsm__Status__c"
        static let complete = "pffsm__Complete__c"
        static let criticalInspection = "pffsm__Critical_Inspection__c"
        static let userPicklist = "pffsm__User_Picklist__c"
        static let userText = "pffsm__User_Text__c"
        static let value = "pffsm__Value__c"
        static let comments = "pffsm__Comments__c"
        static let recommendedAction = "pffsm__Recommended_Action__c"
        static let additionalDetails = "pffsm__Additional_Details__c"
        static let trackCompleteTime = "pffsm__Track_Complete_Time__c"
        static let externalId = "pffsm__PF_External_Id__c"
    }

    enum Picklists {
        static let none = "None"
        static let pass = "Pass"
        static let fail = "Fail"
    }

    enum ContentVersionFields {
        static let id = "Id"
        static let title = "Title"
        static let pathOnClient = "PathOnClient"
        static let versionData = "VersionData"
        static let contentDocumentId = "ContentDocumentId"
    }

    enum ContentDocumentLinkFields {
        static let contentDocumentId = "ContentDocumentId"
        static let linkedEntityId = "LinkedEntityId"
        static let shareType = "ShareType"
        static let visibility = "Visibility"
        static let shareTypeViewer = "V"
        static let visibilityAllUsers = "AllUsers"
    }

    static func sitesQuery() -> String {
        """
        SELECT Id, Name, pffsm__Asset_Class__c, pffsm__Asset_SubClass__c, pffsm__Status__c,
               pffsm__Site_Status__c, pffsm__Plant__c, pffsm__PlantName__c,
               pffsm__Top_Level_Parent__c, pffsm__Geolocation__Latitude__s,
               pffsm__Geolocation__Longitude__s, pffsm__State_Province__c,
               pffsm__Site_Nameplate_Capacity_kW__c, pffsm__Unique_Name__c,
               pffsm__External_Asset_ID__c, pffsm__Asset_UUID__c
        FROM pffsm__smEquipment__c
        WHERE pffsm__Asset_Class__c = 'Plant'
        AND pffsm__Status__c = 'In Service'
        ORDER BY Name
        """
    }

    static func workOrdersForSiteQuery(siteId: String, scheduledDate: Date) -> String {
        """
        SELECT Id, Name, pffsm__Asset__c, pffsm__Status__c, pffsm__WO_Status__c,
               pffsm__WO_Type__c, pffsm__Priority__c, pffsm__Scheduled_Start_Date__c,
               pffsm__Scheduled_Date_Time__c, pffsm__Scheduled_Onsite_Date__c,
               pffsm__Scheduled_Completion_Date__c, pffsm__Site_Name__c,
               pffsm__Site_Type__c, pffsm__Site_Access__c, pffsm__Site_Instructions__c,
               pffsm__Work_Order_18__c, RecordTypeId
        FROM pffsm__smWork_Order__c
        WHERE pffsm__Asset__c = '\(soqlEscape(siteId))'
        AND pffsm__Scheduled_Start_Date__c = TODAY
        ORDER BY pffsm__Scheduled_Start_Date__c, Name
        """
    }

    static func workTasksForWorkOrderQuery(workOrderId: String) -> String {
        """
        SELECT Id, Name, pffsm__Work_Order__c, pffsm__Asset__c, pffsm__Step__c,
               pffsm__Description__c, pffsm__Status__c, pffsm__Schedule_Date__c,
               pffsm__Task_Due_Date__c, pffsm__Standard_Form_Template__c,
               pffsm__Std_Task__c, pffsm__Total_Steps__c,
               pffsm__Task_steps_completed__c, pffsm__WT_Type__c, pffsm__Priority__c,
               pffsm__InstructionsRT__c, pffsm__Form_Values_JSON__c,
               pffsm__Inspection_Form_Completed__c
        FROM pffsm__smWO_Task__c
        WHERE pffsm__Work_Order__c = '\(soqlEscape(workOrderId))'
        ORDER BY pffsm__Step__c, Name
        """
    }

    static func workTaskStepsForTasksQuery(taskIds: [String]) -> String {
        let ids = taskIds.map { "'\(soqlEscape($0))'" }.joined(separator: ",")
        return """
        SELECT Id, Name, pffsm__Work_Task__c, pffsm__Sequence__c, pffsm__Status__c,
               pffsm__Complete__c, pffsm__Critical_Inspection__c,
               pffsm__User_Picklist__c, pffsm__User_Text__c, pffsm__Value__c,
               pffsm__Comments__c, pffsm__Recommended_Action__c,
               pffsm__Additional_Details__c, pffsm__Track_Complete_Time__c,
               pffsm__PF_External_Id__c
        FROM pffsm__Work_Task_Step__c
        WHERE pffsm__Work_Task__c IN (\(ids))
        ORDER BY pffsm__Work_Task__c, pffsm__Sequence__c, Name
        """
    }

    static func workTaskStepPatchPath(stepId: String) -> String {
        "/services/data/\(apiVersion)/sobjects/\(Objects.workTaskStep)/\(stepId)"
    }

    static func contentVersionPath() -> String {
        "/services/data/\(apiVersion)/sobjects/\(Objects.contentVersion)"
    }

    static func contentDocumentLinkPath() -> String {
        "/services/data/\(apiVersion)/sobjects/\(Objects.contentDocumentLink)"
    }

    static func soqlEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}

extension ISO8601DateFormatter {
    static let salesforceInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
