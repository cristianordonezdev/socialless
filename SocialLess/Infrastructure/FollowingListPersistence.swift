import Foundation

@MainActor struct FileFollowingListRepository: FollowingListRepository {
    let url: URL
    func load() throws -> FollowingList? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard data.count <= FollowingListImporter.maximumBytes else { throw FollowingImportError.tooLarge }
        let list = try JSONDecoder().decode(FollowingList.self, from: data)
        try validate(list)
        return list
    }
    func save(_ list: FollowingList) throws {
        try validate(list)
        var directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try JSONEncoder().encode(list).write(to: url, options: [.atomic, .completeFileProtection])
    }
    func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    private func validate(_ list: FollowingList) throws {
        guard !list.accounts.isEmpty, list.accounts.count <= 10_000,
              Set(list.accounts).count == list.accounts.count,
              list.accounts.allSatisfy({ FollowingListImporter.normalize($0) == $0 }) else {
            throw FollowingImportError.invalidFormat
        }
    }
}
