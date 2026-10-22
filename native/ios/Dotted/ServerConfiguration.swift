import Foundation

// Build settings supply the URL through Info.plist. Debug builds can also use
// DOTTED_SERVER_URL in the Xcode scheme's Run environment for local testing.
enum ServerConfiguration {
    static var url: URL {
        let configuredURL = Bundle.main.object(forInfoDictionaryKey: "DottedServerURL") as? String
        #if DEBUG
        let value = ProcessInfo.processInfo.environment["DOTTED_SERVER_URL"] ?? configuredURL
        #else
        let value = configuredURL
        #endif

        guard let value, let url = URL(string: value),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else {
            preconditionFailure("Set DOTTED_SERVER_URL to the Rails server URL.")
        }
        #if DEBUG
        precondition(["http", "https"].contains(url.scheme), "Use an HTTP or HTTPS server URL.")
        #else
        precondition(url.scheme == "https", "Release builds require HTTPS.")
        precondition(host != "dotted.example.com", "Configure the release server before distributing Dotted.")
        #endif
        return url
    }
}
