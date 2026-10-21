import Foundation

struct MeetingLink: Hashable, Sendable {
    let url: URL
    let service: String
    var host: String { url.host ?? "" }
}

/// 通信せず、フィールド優先順・出現順で対応するHTTPS会議URLを返す。
enum MeetingURLExtractor {
    static func extract(url: URL?, location: String?, notes: String?) -> [MeetingLink] {
        var links: [MeetingLink] = []
        // URL型のフィールドは文章用の補正をせず、参加トークンをそのまま保持する。
        if let url, let link = validate(url.absoluteString) { links.append(link) }
        for field in [location, notes].compactMap({ $0 }) {
            // HTMLのhrefと本文の両方を読み、引用符・山括弧で候補を区切る。
            let text = field.replacingOccurrences(of: "&amp;", with: "&")
            for token in text.components(
                separatedBy: .whitespacesAndNewlines.union(
                    CharacterSet(charactersIn: "<>\"'")))
            {
                guard let range = token.range(of: "https://", options: .caseInsensitive) else {
                    continue
                }
                var candidate = String(token[range.lowerBound...])
                // クエリ・fragmentの末尾と句読点は区別できないため変更しない。
                if !candidate.contains("?") && !candidate.contains("#") {
                    candidate = candidate.trimmingCharacters(
                        in: CharacterSet(charactersIn: ").,;!]}、。"))
                }
                guard let link = validate(candidate), !links.contains(link) else { continue }
                links.append(link)
            }
        }
        return links
    }

    private static func validate(_ text: String) -> MeetingLink? {
        guard let components = URLComponents(string: text),
            components.scheme?.lowercased() == "https",
            components.user == nil, components.password == nil,
            components.port == nil || components.port == 443,
            let host = components.host?.lowercased(), let url = components.url
        else { return nil }
        let path = components.path
        guard path.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        func belongs(to domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        func matches(_ pattern: String) -> Bool {
            path.range(of: pattern, options: .regularExpression) != nil
        }
        let service: String
        if host == "meet.google.com", matches("^/[a-z]{3}-[a-z]{4}-[a-z]{3}/?$") {
            service = "Google Meet"
        } else if belongs(to: "zoom.us") || belongs(to: "zoom.com"),
            matches("^/(j/[0-9]+|my/[A-Za-z0-9._-]+)/?$")
        {
            service = "Zoom"
        } else if host == "teams.microsoft.com" || host == "teams.live.com" {
            guard matches("^/(l/meetup-join/[^/]+/[^/]+|meet/[0-9]+)/?$") else {
                return nil
            }
            service = "Microsoft Teams"
        } else if belongs(to: "webex.com"),
            matches(#"^/(meet/[^/]+|join/[^/]+|[^/]+/j\.php)/?$"#)
        {
            service = "Webex"
        } else {
            return nil
        }
        return MeetingLink(url: url, service: service)
    }
}
