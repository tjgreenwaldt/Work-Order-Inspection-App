import Foundation

enum SalesforceEnvironment {
    case sandbox
    case production
}

struct SalesforceConfig {
    let apiVersion: String
    let loginBaseURL: URL
    let instanceBaseURL: URL?
    let connectedAppClientId: String
    let redirectURI: String
    let environment: SalesforceEnvironment
    let useMockClient: Bool

    static let current = SalesforceConfig(
        apiVersion: SalesforceSchema.apiVersion,
        loginBaseURL: URL(string: "https://test.salesforce.com")!,
        instanceBaseURL: nil,
        connectedAppClientId: "TODO_CONNECTED_APP_CLIENT_ID",
        redirectURI: "TODO_REDIRECT_URI",
        environment: .sandbox,
        useMockClient: true
    )

    var isConfiguredForReadOnlyAPI: Bool {
        instanceBaseURL != nil
    }

    func makeAPIClient(session: SalesforceSession? = nil) -> SalesforceAPIClient {
        if useMockClient {
            return MockSalesforceAPIClient()
        }

        return RealSalesforceAPIClient(config: self, session: session)
    }
}
