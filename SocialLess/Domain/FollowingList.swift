import Foundation
import Observation

struct FollowingList: Codable, Equatable {
    let accounts: [String]
    let importedAt: Date
}

enum FollowingImportError: Error {
    case invalidFormat, tooLarge, empty
    var message: String {
        switch self {
        case .invalidFormat: return "Choose the following.json file from an Instagram JSON export. ZIP, HTML and followers files are not supported. Your saved list has not changed."
        case .tooLarge: return "This file is too large. Choose only following.json (up to 5 MB and 10,000 accounts). Your saved list has not changed."
        case .empty: return "This following list is empty. Your saved list has not changed."
        }
    }
}

enum FollowingListImporter {
    static let maximumBytes = 5 * 1024 * 1024
    static func normalize(_ value: String) -> String? {
        guard value.range(of: #"\A[A-Za-z0-9_][A-Za-z0-9_.]{0,29}\z"#, options: .regularExpression) != nil,
              !value.hasSuffix("."), !value.contains("..") else { return nil }
        return value.lowercased()
    }
    static func parse(_ data: Data, now: Date = Date()) throws -> FollowingList {
        guard data.count <= maximumBytes else { throw FollowingImportError.tooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["relationships_following"] as? [[String: Any]] else {
            throw FollowingImportError.invalidFormat
        }
        guard entries.count <= 10_000 else { throw FollowingImportError.tooLarge }
        var accounts = Set<String>()
        for entry in entries {
            // Only the explicit account fields are imported. Never retain URLs, timestamps or the source file.
            let values = entry["string_list_data"] as? [[String: Any]] ?? []
            guard values.count <= 1 else { throw FollowingImportError.invalidFormat }
            let title = entry["title"] as? String
            let value = values.first?["value"] as? String
            let candidates = [title, value].compactMap { $0 }.filter { !$0.isEmpty }
            guard !candidates.isEmpty else { throw FollowingImportError.invalidFormat }
            let normalized = try candidates.map { candidate -> String in
                guard let account = normalize(candidate) else { throw FollowingImportError.invalidFormat }
                return account
            }
            guard Set(normalized).count == 1 else { throw FollowingImportError.invalidFormat }
            accounts.insert(normalized[0])
        }
        guard !accounts.isEmpty else { throw FollowingImportError.empty }
        return FollowingList(accounts: accounts.sorted(), importedAt: now)
    }
    static func read(_ url: URL) throws -> FollowingList {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: maximumBytes + 1) ?? Data()
        return try parse(data)
    }
}

@MainActor protocol FollowingListRepository {
    func load() throws -> FollowingList?
    func save(_ list: FollowingList) throws
    func delete() throws
}

@MainActor final class MemoryFollowingListRepository: FollowingListRepository {
    var list: FollowingList?
    func load() throws -> FollowingList? { list }
    func save(_ list: FollowingList) throws { self.list = list }
    func delete() throws { list = nil }
}

@MainActor @Observable final class FollowingListStore {
    private(set) var list: FollowingList?
    var error: String?
    private let repository: any FollowingListRepository
    init(repository: any FollowingListRepository) {
        self.repository = repository
        do { list = try repository.load() }
        catch { self.error = "Your following list could not be read. Existing data has been kept. You can retry by reopening the app." }
    }
    func replace(with list: FollowingList) {
        do { try repository.save(list); self.list = list; error = nil }
        catch { self.error = "Your following list could not be saved. The previous list has been kept." }
    }
    func delete() {
        do { try repository.delete(); list = nil; error = nil }
        catch { self.error = "Your following list could not be deleted. Please try again." }
    }
}
