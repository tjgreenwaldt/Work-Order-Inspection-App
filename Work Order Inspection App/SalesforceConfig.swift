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
    let oauthScopes: [String]

    static let defaultOrgBaseURL = URL(string: "https://pfdrive-origis.my.salesforce.com")!

    static let current = SalesforceConfig(
        apiVersion: SalesforceSchema.apiVersion,
        loginBaseURL: defaultOrgBaseURL,
        instanceBaseURL: defaultOrgBaseURL,
        connectedAppClientId: "TODO_CONNECTED_APP_CLIENT_ID",
        redirectURI: "work-order-inspection-app://oauth/callback",
        environment: .production,
        useMockClient: true,
        oauthScopes: ["api", "refresh_token", "openid", "profile"]
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

    var callbackURLScheme: String {
        URLComponents(string: redirectURI)?.scheme ?? redirectURI
    }
}
