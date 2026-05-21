import Combine
import Foundation
import SwiftUI

struct WorkOrderSyncMessage: Equatable {
    let message: String
    let detail: String?
}

#if DEBUG
// DEBUG backend modes keep the same app flow while swapping only the Salesforce boundary:
// mock data, a manually pasted real session, or the configured OAuth login.
enum AppBackendSelection: String, CaseIterable, Identifiable {
    case mock = "Mock Salesforce"
    case realManual = "Real Salesforce - Manual Session"
    case realOAuth = "Real Salesforce - OAuth"

    var id: String { rawValue }
}
#endif

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var apiClient: SalesforceAPIClient

    @Published var session: SalesforceSession?
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var selectedSite: SiteDTO?
    @Published var lastSuccessfulSync: Date?
    @Published var lastSyncError: String?
    @Published private var workOrderSyncMessages: [String: WorkOrderSyncMessage] = [:]
    #if DEBUG
    @Published var selectedBackend: AppBackendSelection
    @Published var manualInstanceURLText = "https://pfdrive-origis.my.salesforce.com"
    @Published var manualAccessToken = ""
    #endif

    var isAuthenticated: Bool { session != nil }
    var isUsingMockClient: Bool {
        apiClient is MockSalesforceAPIClient
    }

    var backendTypeName: String {
        apiClient is MockSalesforceAPIClient ? "Mock" : "Real Salesforce"
    }

    init(apiClient: SalesforceAPIClient) {
        self.apiClient = apiClient
        #if DEBUG
        self.selectedBackend = apiClient is MockSalesforceAPIClient ? .mock : .realOAuth
        #endif
    }

    private var authService: SalesforceAuthService {
        SalesforceAuthService(apiClient: apiClient)
    }

    #if DEBUG
    func selectBackend(_ backend: AppBackendSelection) {
        guard backend != selectedBackend else { return }
        selectedBackend = backend
        rebuildAPIClientForSelectedBackend()
        session = nil
        selectedSite = nil
        authError = backend == .mock ? nil : "Salesforce login required."
    }

    func updateManualSession(instanceURLText: String? = nil, accessToken: String? = nil) {
        if let instanceURLText {
            manualInstanceURLText = instanceURLText
        }
        if let accessToken {
            manualAccessToken = accessToken
        }
        guard selectedBackend == .realManual else { return }
        rebuildAPIClientForSelectedBackend()
        session = manualSession()
        authError = session == nil ? "Salesforce session is not configured." : nil
    }

    func clearManualSession() {
        manualInstanceURLText = "https://pfdrive-origis.my.salesforce.com"
        manualAccessToken = ""
        if selectedBackend == .realManual {
            rebuildAPIClientForSelectedBackend()
            session = nil
            authError = "Salesforce session is not configured."
        }
    }

    private func rebuildAPIClientForSelectedBackend() {
        switch selectedBackend {
        case .mock:
            apiClient = MockSalesforceAPIClient()
        case .realManual:
            // Manual sessions are intentionally ephemeral so pasted tokens are not persisted.
            let session = manualSession()
            apiClient = RealSalesforceAPIClient(config: .current, session: session, tokenStore: EphemeralSalesforceTokenStore())
        case .realOAuth:
            // OAuth sessions use the normal keychain-backed token store and refresh path.
            apiClient = RealSalesforceAPIClient(config: .current)
        }
    }

    private func manualSession() -> SalesforceSession? {
        let trimmedURL = manualInstanceURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = manualAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let instanceURL = URL(string: trimmedURL), trimmedToken.isEmpty == false else {
            return nil
        }
        return SalesforceSession(accessToken: trimmedToken, refreshToken: nil, instanceURL: instanceURL, issuedAt: Date(), expiresAt: nil)
    }
    #endif

    func mockLogin() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        authError = nil
        do {
            #if DEBUG
            if selectedBackend == .realManual {
                guard let manualSession = manualSession() else {
                    throw SalesforceAPIError.sessionNotConfigured
                }
                rebuildAPIClientForSelectedBackend()
                session = manualSession
                return
            }
            #endif
            session = try await authService.mockLogin()
        } catch {
            authError = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await authService.logout()
        } catch {
            authError = error.localizedDescription
        }
        session = nil
        selectedSite = nil
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
        // Submit is local-first: failed uploads keep the inspection saved in SwiftData and surface retry guidance.
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
        try await apiClient.authenticate()
    }

    func logout() async throws {
        try await apiClient.logout()
    }
}
