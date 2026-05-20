import Combine
import Foundation
import SwiftUI

struct WorkOrderSyncMessage: Equatable {
    let message: String
    let detail: String?
}

@MainActor
final class AppEnvironment: ObservableObject {
    let apiClient: SalesforceAPIClient
    let authService: SalesforceAuthService

    @Published var session: SalesforceSession?
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var selectedSite: SiteDTO?
    @Published var lastSuccessfulSync: Date?
    @Published var lastSyncError: String?
    @Published private var workOrderSyncMessages: [String: WorkOrderSyncMessage] = [:]

    var isAuthenticated: Bool { session != nil }
    var backendTypeName: String {
        apiClient is MockSalesforceAPIClient ? "Mock" : "Real Salesforce"
    }

    init(apiClient: SalesforceAPIClient) {
        self.apiClient = apiClient
        self.authService = SalesforceAuthService(apiClient: apiClient)
    }

    func mockLogin() async {
        isAuthenticating = true
        authError = nil
        do {
            session = try await authService.mockLogin()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    func selectSite(_ site: SiteDTO) {
        selectedSite = site
    }

    func recordSyncSuccess(at date: Date = Date()) {
        lastSuccessfulSync = date
        lastSyncError = nil
    }

    func recordSyncFailure(_ message: String) {
        lastSyncError = message
    }

    func syncMessage(for workOrderId: String) -> WorkOrderSyncMessage? {
        workOrderSyncMessages[workOrderId]
    }

    func recordWorkOrderSyncSuccess(workOrderId: String, at date: Date = Date()) {
        recordSyncSuccess(at: date)
        workOrderSyncMessages[workOrderId] = WorkOrderSyncMessage(
            message: "Inspection submitted and synced.",
            detail: nil
        )
    }

    func recordWorkOrderSyncFailure(workOrderId: String, error: Error, isConnectivityError: Bool) {
        let detail = error.localizedDescription
        recordSyncFailure(detail)
        workOrderSyncMessages[workOrderId] = WorkOrderSyncMessage(
            message: isConnectivityError
                ? "Changes are saved locally. Sync will resume when connectivity returns."
                : "Changes are saved locally, but sync failed. Please retry. If it fails again, contact support with the sync error details.",
            detail: isConnectivityError ? nil : detail
        )
    }
}

struct SalesforceAuthService {
    let apiClient: SalesforceAPIClient

    func mockLogin() async throws -> SalesforceSession {
        try await apiClient.authenticate()
    }

    func beginOAuthLogin() async throws -> SalesforceSession {
        // TODO: Build OAuth 2.0 Authorization Code with PKCE flow.
        // TODO: Connected App client ID.
        // TODO: Redirect URI registered in Salesforce.
        // TODO: Login domain, such as login.salesforce.com or a My Domain host.
        // TODO: OAuth scopes, including API and refresh token scopes as appropriate.
        // TODO: Token refresh and secure keychain persistence.
        try await apiClient.authenticate()
    }
}
