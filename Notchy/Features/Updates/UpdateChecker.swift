import Foundation

/// Talks to GitHub Releases API. Returns the latest published release as a
/// lightweight `ReleaseInfo` struct. No external dependencies — uses
/// `URLSession` + `JSONSerialization`.
actor UpdateChecker {

    struct ReleaseInfo: Sendable, Equatable {
        let tagName: String          // e.g. "v0.5.0"
        let version: SemVer          // parsed from tagName
        let name: String             // human title, may be == tagName
        let body: String             // markdown changelog (truncated for UI)
        let htmlURL: URL             // GH release page (where user clicks "Download")
        let zipDownloadURL: URL?     // first .zip asset, if any
    }

    enum CheckError: Error {
        case noNetwork
        case rateLimited
        case malformedResponse
        case tagNotParseable(String)
    }

    private let owner: String
    private let repo: String
    private let session: URLSession

    init(owner: String = "OtaruTech", repo: String = "notchy") {
        self.owner = owner
        self.repo = repo
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 12
        self.session = URLSession(configuration: cfg)
    }

    func fetchLatest() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Notchy/auto-update", forHTTPHeaderField: "User-Agent")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw CheckError.noNetwork
        }

        guard let http = resp as? HTTPURLResponse else { throw CheckError.malformedResponse }
        if http.statusCode == 403 || http.statusCode == 429 { throw CheckError.rateLimited }
        guard http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw CheckError.malformedResponse }

        guard let tag = json["tag_name"] as? String,
              let htmlString = json["html_url"] as? String,
              let html = URL(string: htmlString)
        else { throw CheckError.malformedResponse }
        guard let version = SemVer(tag) else {
            throw CheckError.tagNotParseable(tag)
        }

        let name = (json["name"] as? String) ?? tag
        let body = (json["body"] as? String) ?? ""

        var zipURL: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                guard let name = asset["name"] as? String,
                      let urlStr = asset["browser_download_url"] as? String,
                      let url = URL(string: urlStr)
                else { continue }
                if name.lowercased().hasSuffix(".zip") {
                    zipURL = url
                    break
                }
            }
        }

        return ReleaseInfo(
            tagName: tag, version: version, name: name,
            body: body, htmlURL: html, zipDownloadURL: zipURL
        )
    }
}
